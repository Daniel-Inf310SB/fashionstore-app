import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../models/ai_assistant.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/ai_assistant_session_service.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/reservation_service.dart';
import '../../services/selected_branch_service.dart';


// Tema propio del asistente, independiente del tema oscuro legado.
class _AssistantPalette {
  static const Color background = Color(0xFFF7F7F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF151515);
  static const Color primaryLight = Color(0xFF151515);
  static const Color textPrimary = Color(0xFF151515);
  static const Color textSecondary = Color(0xFF626262);
  static const Color textMuted = Color(0xFF888888);
  static const Color divider = Color(0xFFE4E4E4);
  static const Color success = Color(0xFF16805B);
  static const Color warning = Color(0xFF9B681D);
  static const Color error = Color(0xFFC43949);
}

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({
    super.key,
    required this.currentPage,
    this.productId,
    this.variantId,
    this.cartItemId,
    this.reservationId,
  });

  final String currentPage;
  final int? productId;
  final int? variantId;
  final int? cartItemId;
  final int? reservationId;

  @override
  State<AIAssistantScreen> createState() =>
      _AIAssistantScreenState();
}

class _AIAssistantScreenState
    extends State<AIAssistantScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _chatController = TextEditingController();
  final _commandController = TextEditingController();
  final _chatScrollController = ScrollController();

  final SpeechToText _speech = SpeechToText();

  final List<AssistantChatMessage> _messages =
      AIAssistantSessionService.messages;

  static const _quickQuestions = <String>[
    'Necesito un outfit para una entrevista de trabajo.',
    '¿Qué prendas me recomiendas para una cena elegante?',
    'Muéstrame opciones de hasta 300 Bs.',
    '¿Qué puedo combinar para un look casual de fin de semana?',
  ];

  static const _commandExamples = <String>[
    'Ver mi carrito',
    'Ir a mis compras',
    'Ver mis reservas',
    'Buscar camisas para mujer',
    'Agrega este producto al carrito',
    'Aumenta 2 unidades de este producto',
    'Vacía mi carrito',
    'Ir a pagar',
  ];

  bool _chatLoading = false;
  bool _commandLoading = false;
  bool _commandExecuting = false;
  bool _listening = false;
  bool _speechAvailable = false;

  String _chatError = '';
  String _commandError = '';
  String _commandMessage = '';

  CustomerAssistantResolvedCommand? _pendingConfirmation;

  bool get _commandBusy =>
      _commandLoading ||
      _commandExecuting ||
      _listening;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
    );

    _initializeSpeech();
  }

  @override
  void dispose() {
    _speech.cancel();
    _tabController.dispose();
    _chatController.dispose();
    _commandController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;

          if (status == 'done' ||
              status == 'notListening') {
            setState(() {
              _listening = false;
            });
          }
        },
        onError: (error) {
          if (!mounted) return;

          setState(() {
            _listening = false;
            _commandMessage = '';
            _commandError =
                'No pude reconocer la voz. Puedes escribir el comando.';
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _speechAvailable = available;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _speechAvailable = false;
      });
    }
  }

  Future<bool> _ensureLoggedIn() async {
    final loggedIn =
        await AuthService.isLoggedIn();

    if (loggedIn) return true;

    if (!mounted) return false;

    _showSnack(
      'Inicia sesión para usar el asistente.',
      error: true,
    );

    return false;
  }

  Future<void> _sendChat() async {
    final text =
        _chatController.text.trim();

    if (text.length < 2 ||
        _chatLoading) {
      return;
    }

    if (!await _ensureLoggedIn()) {
      return;
    }

    await SelectedBranchService.initialize();

    final branch =
        SelectedBranchService.selectedBranch;

    if (!mounted) return;

    if (branch == null) {
      setState(() {
        _chatError =
            'Selecciona una sucursal para consultar disponibilidad real.';
      });
      return;
    }

    setState(() {
      _messages.add(
        AssistantChatMessage(
          role: 'user',
          text: text,
        ),
      );
      _chatController.clear();
      _chatLoading = true;
      _chatError = '';
    });

    _scrollChat();

    try {
      final response =
          await AIAssistantService.ask(
        branchId: branch.id,
        message: text,
        maxProducts: 6,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(
          AssistantChatMessage(
            role: 'assistant',
            text: response.message,
            products: response.products,
          ),
        );
      });

      _scrollChat();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _chatError = error
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    } finally {
      if (mounted) {
        setState(() {
          _chatLoading = false;
        });
      }
    }
  }

  Future<void> _runCommand() async {
    final text =
        _commandController.text.trim();

    if (text.length < 2 ||
        _commandLoading ||
        _commandExecuting) {
      return;
    }

    if (!await _ensureLoggedIn()) {
      return;
    }

    await SelectedBranchService.initialize();

    final branch =
        SelectedBranchService.selectedBranch;

    if (!mounted) return;

    setState(() {
      _commandLoading = true;
      _commandError = '';
      _commandMessage =
          'Interpretando comando…';
      _pendingConfirmation = null;
    });

    try {
      final response =
          await AIAssistantService.interpret(
        command: text,
        context: CustomerAssistantContext(
          currentPage: widget.currentPage,
          branchId: branch?.id,
          productId: widget.productId,
          variantId: widget.variantId,
          cartItemId: widget.cartItemId,
          reservationId:
              widget.reservationId,
        ),
      );

      if (!mounted) return;

      final result = response.result;

      setState(() {
        _commandMessage =
            result.message;
      });

      if (!result.canExecute) {
        final unresolved =
            result.unresolved;

        setState(() {
          _commandError =
              unresolved.isNotEmpty
                  ? 'Falta precisar: ${unresolved.join(', ')}.'
                  : result.message.isNotEmpty
                      ? result.message
                      : 'No pude interpretar ese comando con suficiente seguridad.';
        });

        return;
      }

      if (result.requiresConfirmation) {
        setState(() {
          _pendingConfirmation =
              result;
        });

        return;
      }

      if (result.navigation != null) {
        _commandController.clear();
        await _returnNavigation(
          result.navigation!,
          result.message,
        );
        return;
      }

      await _executeResolved(
        result,
        confirmed: false,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _commandMessage = '';
        _commandError = error
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    } finally {
      if (mounted) {
        setState(() {
          _commandLoading = false;
        });
      }
    }
  }

  Future<void> _executeResolved(
    CustomerAssistantResolvedCommand command, {
    required bool confirmed,
  }) async {
    if (_commandExecuting) return;

    setState(() {
      _commandExecuting = true;
      _commandError = '';
      _commandMessage = confirmed
          ? 'Confirmando acción…'
          : 'Ejecutando…';
      _pendingConfirmation = null;
    });

    try {
      final response =
          await AIAssistantService.execute(
        command: command,
        confirmed: confirmed,
      );

      if (!mounted) return;

      setState(() {
        _commandMessage =
            response.message.isNotEmpty
                ? response.message
                : 'Acción realizada correctamente.';
        _commandController.clear();
      });

      await _refreshAfterAction(
        command.action,
      );

      final navigation =
          response.navigation ??
          command.navigation;

      if (navigation != null) {
        await _returnNavigation(
          navigation,
          _commandMessage,
        );
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _commandMessage = '';
        _commandError = error
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    } finally {
      if (mounted) {
        setState(() {
          _commandExecuting = false;
        });
      }
    }
  }

  Future<void> _refreshAfterAction(
    String action,
  ) async {
    await SelectedBranchService.initialize();

    final branch =
        SelectedBranchService.selectedBranch;

    if (action.startsWith('CART_') &&
        branch != null) {
      try {
        await CartService.getMyCartCount(
          branch.id,
        );
      } catch (_) {}
    }

    if (action.startsWith(
      'RESERVATION_',
    )) {
      try {
        await ReservationService
            .getMyReservationCount();
      } catch (_) {}
    }
  }

  Future<void> _confirmPending() async {
    final pending =
        _pendingConfirmation;

    if (pending == null) return;

    await _executeResolved(
      pending,
      confirmed: true,
    );
  }

  void _cancelPending() {
    setState(() {
      _pendingConfirmation = null;
      _commandMessage =
          'Acción cancelada. No se realizó ningún cambio.';
      _commandError = '';
    });
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();

      if (!mounted) return;

      setState(() {
        _listening = false;
      });

      return;
    }

    if (_commandLoading ||
        _commandExecuting) {
      return;
    }

    if (!await _ensureLoggedIn()) {
      return;
    }

    final permission =
        await Permission.microphone.request();

    if (!mounted) return;

    if (!permission.isGranted) {
      setState(() {
        _commandError = permission
                .isPermanentlyDenied
            ? 'El permiso del micrófono está bloqueado. Habilítalo en la configuración de FashionStore.'
            : 'No se concedió permiso para usar el micrófono.';
      });
      return;
    }

    if (!_speechAvailable) {
      await _initializeSpeech();
    }

    if (!_speechAvailable) {
      setState(() {
        _commandError =
            'El reconocimiento de voz no está disponible en este dispositivo.';
      });
      return;
    }

    setState(() {
      _listening = true;
      _commandError = '';
      _commandMessage =
          'Escuchando… habla ahora.';
    });

    await _speech.listen(
      localeId: 'es_BO',
      listenMode:
          ListenMode.confirmation,
      onResult: (result) async {
        final text =
            result.recognizedWords.trim();

        if (!mounted ||
            text.isEmpty) {
          return;
        }

        _commandController.text =
            text;

        setState(() {
          _commandMessage =
              'Escuché: “$text”';
        });

        if (result.finalResult) {
          await _speech.stop();

          if (!mounted) return;

          setState(() {
            _listening = false;
          });

          await _runCommand();
        }
      },
    );
  }

  Future<void> _returnNavigation(
    CustomerAssistantNavigation navigation,
    String message,
  ) async {
    if (!mounted) return;

    if (message.trim().isNotEmpty) {
      _showSnack(message);
    }

    Navigator.pop(
      context,
      navigation,
    );
  }

  void _openProduct(
    AIAssistantProduct product,
  ) {
    Navigator.pop(
      context,
      CustomerAssistantNavigation(
        target: 'PRODUCT',
        params: {
          'product_id':
              product.productId,
          if (product.variantId != null)
            'variant_id':
                product.variantId,
        },
        query: const {},
      ),
    );
  }

  void _scrollChat() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!_chatScrollController
          .hasClients) {
        return;
      }

      _chatScrollController.animateTo(
        _chatScrollController
            .position.maxScrollExtent,
        duration:
            const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnack(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? _AssistantPalette.error
            : _AssistantPalette.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        brightness: Brightness.light,
        scaffoldBackgroundColor: _AssistantPalette.background,
        colorScheme: const ColorScheme.light(
          primary: _AssistantPalette.primary,
          onPrimary: Colors.white,
          surface: _AssistantPalette.surface,
          onSurface: _AssistantPalette.textPrimary,
          error: _AssistantPalette.error,
        ),
        textTheme: base.textTheme.apply(
          bodyColor: _AssistantPalette.textPrimary,
          displayColor: _AssistantPalette.textPrimary,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: _AssistantPalette.surface,
          disabledColor: _AssistantPalette.background,
          selectedColor: _AssistantPalette.primary,
          labelStyle: const TextStyle(
            color: _AssistantPalette.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          side: const BorderSide(color: _AssistantPalette.divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _AssistantPalette.background,
          hintStyle: const TextStyle(color: _AssistantPalette.textMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: _AssistantPalette.divider),
            borderRadius: BorderRadius.circular(6),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _AssistantPalette.divider),
            borderRadius: BorderRadius.circular(6),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _AssistantPalette.primary, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _AssistantPalette.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _AssistantPalette.primary,
            side: const BorderSide(color: _AssistantPalette.primary),
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: _AssistantPalette.background,
        appBar: AppBar(
          backgroundColor: _AssistantPalette.surface,
          foregroundColor: _AssistantPalette.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 86,
          titleSpacing: 4,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FASHIONSTORE AI',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.4),
              ),
              const SizedBox(height: 5),
              ValueListenableBuilder(
                valueListenable: SelectedBranchService.selectedBranchNotifier,
                builder: (context, branch, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront_outlined, size: 13, color: _AssistantPalette.textMuted),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        branch?.name ?? 'Selecciona una sucursal',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _AssistantPalette.textMuted, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: _AssistantPalette.primary,
            indicatorWeight: 3,
            labelColor: _AssistantPalette.textPrimary,
            unselectedLabelColor: _AssistantPalette.textMuted,
            dividerColor: _AssistantPalette.divider,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.auto_awesome_outlined, size: 21), text: 'Asistente'),
              Tab(icon: Icon(Icons.graphic_eq_outlined, size: 21), text: 'Comandos'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildAssistantTab(), _buildCommandsTab()],
        ),
      ),
    );
  }

  Widget _buildAssistantTab() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller:
                _chatScrollController,
            padding:
                const EdgeInsets.fromLTRB(
              14,
              16,
              14,
              8,
            ),
            children: [
              if (_messages.length <= 1) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _AssistantPalette.surface,
                    border: Border.all(color: _AssistantPalette.divider),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.auto_awesome_outlined, size: 17),
                        SizedBox(width: 8),
                        Text('TU ASESOR DE ESTILO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                      ]),
                      SizedBox(height: 12),
                      Text('¿Qué look buscas hoy?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.15)),
                      SizedBox(height: 8),
                      Text('Inspírate, descubre prendas y encuentra combinaciones disponibles en tu sucursal.', style: TextStyle(color: _AssistantPalette.textSecondary, height: 1.4)),
                    ],
                  ),
                ),
              ],
              for (final item
                  in _messages)
                _ChatBubble(
                  message: item,
                  onProductTap:
                      _openProduct,
                ),
              if (_messages.length == 1 &&
                  !_chatLoading) ...[
                const SizedBox(
                  height: 8,
                ),
                const Text(
                  'INSPÍRATE CON ESTAS IDEAS',
                  style: TextStyle(
                    color:
                        _AssistantPalette.textMuted,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                ..._quickQuestions.map(
                  (question) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: _AssistantPalette.surface,
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        onTap: () { _chatController.text = question; },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: _AssistantPalette.divider),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome_outlined, size: 17, color: _AssistantPalette.textSecondary),
                              const SizedBox(width: 12),
                              Expanded(child: Text(question, style: const TextStyle(fontSize: 13, color: _AssistantPalette.textPrimary, height: 1.3))),
                              const SizedBox(width: 7),
                              const Icon(Icons.north_west_rounded, size: 16, color: _AssistantPalette.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (_chatLoading) ...[
                const SizedBox(
                  height: 10,
                ),
                const Align(
                  alignment:
                      Alignment.centerLeft,
                  child:
                      _TypingBubble(),
                ),
              ],
              if (_chatError.isNotEmpty) ...[
                const SizedBox(
                  height: 10,
                ),
                _ErrorBox(
                  message:
                      _chatError,
                ),
              ],
            ],
          ),
        ),
        _Composer(
          controller:
              _chatController,
          hint:
              'Ej. ¿Qué puedo usar para una entrevista?',
          busy: _chatLoading,
          onSend:
              _sendChat,
        ),
      ],
    );
  }

  Widget _buildCommandsTab() {
    final pending =
        _pendingConfirmation;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              18,
              16,
              10,
            ),
            children: [
              const Text(
                'COMANDOS INTELIGENTES',
                style: TextStyle(
                  color:
                      _AssistantPalette.primaryLight,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              const Text(
                'Controla tu experiencia',
                style: TextStyle(
                  color:
                      _AssistantPalette.textPrimary,
                  fontSize: 24,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(
                height: 6,
              ),
              const Text(
                'Puedes navegar, buscar productos y gestionar carrito o reservas usando texto o tu voz.',
                style: TextStyle(
                  color:
                      _AssistantPalette.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(
                height: 14,
              ),
              ..._commandExamples.map(
                (example) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: _AssistantPalette.surface,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: _commandBusy ? null : () {
                        _commandController.text = example;
                        setState(() {
                          _commandError = '';
                          _commandMessage = '';
                          _pendingConfirmation = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          border: Border.all(color: _AssistantPalette.divider),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(children: [
                          const Icon(Icons.bolt_outlined, size: 18, color: _AssistantPalette.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(child: Text(example, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: _AssistantPalette.textMuted),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              if (_commandMessage
                  .isNotEmpty) ...[
                const SizedBox(
                  height: 14,
                ),
                _StatusBox(
                  message:
                      _commandMessage,
                  listening:
                      _listening,
                ),
              ],
              if (_commandError
                  .isNotEmpty) ...[
                const SizedBox(
                  height: 10,
                ),
                _ErrorBox(
                  message:
                      _commandError,
                ),
              ],
              if (pending != null) ...[
                const SizedBox(
                  height: 14,
                ),
                _ConfirmationCard(
                  message:
                      pending.confirmationMessage ??
                      pending.message,
                  busy:
                      _commandExecuting,
                  onCancel:
                      _cancelPending,
                  onConfirm:
                      _confirmPending,
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(
              12,
              10,
              12,
              12,
            ),
            decoration: const BoxDecoration(
              color:
                  _AssistantPalette.surface,
              border: Border(
                top: BorderSide(
                  color:
                      _AssistantPalette.divider,
                ),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller:
                      _commandController,
                  enabled:
                      !_commandBusy,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 700,
                  style: const TextStyle(
                    color:
                        _AssistantPalette.textPrimary,
                  ),
                  decoration:
                      const InputDecoration(
                    counterText: '',
                    hintText:
                        'Ej. agrega este producto al carrito, ver mis reservas, ir a pagar...',
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Row(
                  children: [
                    Expanded(
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            _commandLoading ||
                                    _commandExecuting
                                ? null
                                : _toggleVoice,
                        icon: Icon(
                          _listening
                              ? Icons
                                  .stop_rounded
                              : Icons
                                  .mic_rounded,
                        ),
                        label: Text(
                          _listening
                              ? 'Detener'
                              : 'Hablar',
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 9,
                    ),
                    Expanded(
                      child:
                          FilledButton.icon(
                        onPressed:
                            _commandBusy
                                ? null
                                : _runCommand,
                        icon: _commandLoading ||
                                _commandExecuting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .bolt_rounded,
                              ),
                        label: Text(
                          _commandLoading ||
                                  _commandExecuting
                              ? 'Procesando'
                              : 'Ejecutar',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.onProductTap,
  });

  final AssistantChatMessage message;
  final ValueChanged<AIAssistantProduct>
      onProductTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints:
            const BoxConstraints(
          maxWidth: 330,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),
        padding:
            const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isUser
              ? _AssistantPalette.primary
              : _AssistantPalette.surface,
          borderRadius:
              BorderRadius.circular(7),
          border: message.isUser
              ? null
              : Border.all(
                  color:
                      _AssistantPalette.divider,
                ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser
                    ? Colors.white
                    : _AssistantPalette.textPrimary,
                height: 1.38,
              ),
            ),
            if (message.products
                .isNotEmpty) ...[
              const SizedBox(
                height: 10,
              ),
              ...message.products.map(
                (product) =>
                    InkWell(
                  onTap: () =>
                      onProductTap(
                    product,
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style:
                                const TextStyle(
                              color:
                                  _AssistantPalette.primaryLight,
                              fontWeight:
                                  FontWeight.w700,
                              fontSize:
                                  12,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons
                              .arrow_forward_rounded,
                          color:
                              _AssistantPalette.primaryLight,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: _AssistantPalette.surface,
        borderRadius:
            BorderRadius.circular(7),
        border: Border.all(
          color: _AssistantPalette.divider,
        ),
      ),
      child: const Text(
        'Pensando…',
        style: TextStyle(
          color:
              _AssistantPalette.textSecondary,
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hint,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          12,
        ),
        decoration: const BoxDecoration(
          color: _AssistantPalette.surface,
          border: Border(
            top: BorderSide(
              color:
                  _AssistantPalette.divider,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller:
                    controller,
                enabled: !busy,
                minLines: 1,
                maxLines: 3,
                maxLength: 800,
                style: const TextStyle(
                  color:
                      _AssistantPalette.textPrimary,
                ),
                decoration:
                    InputDecoration(
                  counterText: '',
                  hintText: hint,
                ),
                onSubmitted: (_) {
                  if (!busy) onSend();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: busy ? null : onSend,
              style: IconButton.styleFrom(
                backgroundColor: _AssistantPalette.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(50, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({
    required this.message,
    required this.listening,
  });

  final String message;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AssistantPalette.primary
            .withValues(alpha: 0.09),
        borderRadius:
            BorderRadius.circular(7),
        border: Border.all(
          color: _AssistantPalette.primary
              .withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            listening
                ? Icons.mic_rounded
                : Icons
                    .auto_awesome_rounded,
            color:
                _AssistantPalette.primaryLight,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color:
                    _AssistantPalette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AssistantPalette.error
            .withValues(alpha: 0.09),
        borderRadius:
            BorderRadius.circular(7),
        border: Border.all(
          color: _AssistantPalette.error
              .withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color:
              _AssistantPalette.textSecondary,
        ),
      ),
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({
    required this.message,
    required this.busy,
    required this.onCancel,
    required this.onConfirm,
  });

  final String message;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AssistantPalette.surface,
        borderRadius:
            BorderRadius.circular(7),
        border: Border.all(
          color: _AssistantPalette.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'CONFIRMACIÓN REQUERIDA',
            style: TextStyle(
              color:
                  _AssistantPalette.warning,
              fontSize: 9,
              fontWeight:
                  FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color:
                  _AssistantPalette.textPrimary,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'La IA no ejecutará esta acción hasta que la confirmes.',
            style: TextStyle(
              color:
                  _AssistantPalette.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child:
                    OutlinedButton(
                  onPressed:
                      busy
                          ? null
                          : onCancel,
                  child:
                      const Text(
                    'Cancelar',
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child:
                    FilledButton(
                  onPressed:
                      busy
                          ? null
                          : onConfirm,
                  child:
                      const Text(
                    'Confirmar',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
