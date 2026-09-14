import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../main_navigation_screen.dart';


class CompleteProfileScreen
    extends StatefulWidget {
  final Map<String, dynamic>? user;


  const CompleteProfileScreen({
    super.key,
    this.user,
  });


  @override
  State<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}


class _CompleteProfileScreenState
    extends State<CompleteProfileScreen> {
  final _formKey =
      GlobalKey<FormState>();


  final _usernameController =
      TextEditingController();

  final _phoneController =
      TextEditingController();

  final _documentController =
      TextEditingController();

  final _addressController =
      TextEditingController();


  Timer? _usernameDebounce;

  Timer? _documentDebounce;


  bool _isLoading = false;

  bool _isCheckingUsername = false;

  bool _isCheckingDocument = false;


  bool? _usernameAvailable;

  bool? _documentAvailable;


  List<String> _usernameSuggestions = [];


  int? _selectedDay;

  int? _selectedMonth;

  int? _selectedYear;


  String? _selectedAvatarUrl;


  // =========================
  // AVATARES FASHIONSTORE
  // =========================

  static const List<String> _avatars = [
    'https://api.dicebear.com/10.x/lorelei/png?seed=FashionStoreNova&backgroundColor=2f80ff',

    'https://api.dicebear.com/10.x/lorelei/png?seed=FashionStoreLuna&backgroundColor=6aa8ff',

    'https://api.dicebear.com/10.x/lorelei/png?seed=FashionStoreEcho&backgroundColor=b6e3f4',

    'https://api.dicebear.com/10.x/lorelei/png?seed=FashionStoreMilo&backgroundColor=c0aede',

    'https://api.dicebear.com/10.x/lorelei/png?seed=FashionStoreAria&backgroundColor=ffd5dc',

    'https://api.dicebear.com/10.x/lorelei/png?seed=FashionStoreKai&backgroundColor=d1d4f9',

    'https://api.dicebear.com/10.x/lorelei/png?seed=FashionStoreNiko&backgroundColor=ffdfbf',

    'https://api.dicebear.com/10.x/lorelei/png?seed=FashionStoreZoe&backgroundColor=b6e3f4',

    'https://api.dicebear.com/10.x/lorelei/png?seed=FashionStoreRio&backgroundColor=c0aede',

    'https://api.dicebear.com/10.x/lorelei/png?seed=FashionStoreSky&backgroundColor=d1d4f9',
  ];


  @override
  void initState() {
    super.initState();


    final dateString =
        widget.user?['date_of_birth']
            ?.toString();


    if (dateString != null &&
        dateString.isNotEmpty) {
      final date =
          DateTime.tryParse(
        dateString,
      );


      if (date != null) {
        _selectedDay =
            date.day;

        _selectedMonth =
            date.month;

        _selectedYear =
            date.year;
      }
    }


    final username =
        widget.user?['username']
            ?.toString();


    if (username != null &&
        username.isNotEmpty) {
      _usernameController.text =
          username;
    }


    _phoneController.text =
        widget.user?['phone']
                ?.toString() ??
            '';

    _documentController.text =
        widget.user?['document_number']
                ?.toString() ??
            '';

    _addressController.text =
        widget.user?['address']
                ?.toString() ??
            '';


    final photoUrl =
        widget.user?['photo_url']
            ?.toString();


    if (photoUrl != null &&
        photoUrl.isNotEmpty) {
      _selectedAvatarUrl =
          photoUrl;
    } else {
      _selectedAvatarUrl =
          _avatars.first;
    }
  }


  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _documentDebounce?.cancel();

    _usernameController.dispose();
    _phoneController.dispose();
    _documentController.dispose();
    _addressController.dispose();

    super.dispose();
  }


  // =========================
  // AVATAR
  // =========================

  void _selectAvatar(
    String avatarUrl,
  ) {
    if (_isLoading) {
      return;
    }


    setState(() {
      _selectedAvatarUrl =
          avatarUrl;
    });
  }


  // =========================
  // USERNAME
  // =========================

  void _onUsernameChanged(
    String value,
  ) {
    _usernameDebounce?.cancel();


    setState(() {
      _usernameAvailable =
          null;

      _usernameSuggestions =
          [];
    });


    final username =
        value.trim();


    if (username.length <
        3) {
      return;
    }


    final validUsername =
        RegExp(
      r'^[a-zA-Z0-9._]+$',
    );


    if (!validUsername.hasMatch(
      username,
    )) {
      return;
    }


    _usernameDebounce =
        Timer(
      const Duration(
        milliseconds:
            600,
      ),
      () {
        _checkUsername(
          username,
        );
      },
    );
  }


  Future<void> _checkUsername(
    String username,
  ) async {
    if (!mounted) {
      return;
    }


    setState(() {
      _isCheckingUsername =
          true;
    });


    try {
      final result =
          await AuthService.checkUsername(
        username,
      );


      if (!mounted) {
        return;
      }


      final currentText =
          _usernameController.text
              .trim()
              .toLowerCase();


      final checkedUsername =
          result['username']
              ?.toString()
              .toLowerCase();


      if (currentText !=
          checkedUsername) {
        return;
      }


      final rawSuggestions =
          result['suggestions'];


      setState(() {
        _usernameAvailable =
            result['available'] ==
                true;


        if (rawSuggestions
            is List) {
          _usernameSuggestions =
              rawSuggestions
                  .map(
                    (item) =>
                        item.toString(),
                  )
                  .toList();
        } else {
          _usernameSuggestions =
              [];
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }


      setState(() {
        _usernameAvailable =
            null;

        _usernameSuggestions =
            [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUsername =
              false;
        });
      }
    }
  }


  void _useSuggestion(
    String username,
  ) {
    _usernameController.text =
        username;


    _usernameController.selection =
        TextSelection.collapsed(
      offset:
          username.length,
    );


    _onUsernameChanged(
      username,
    );
  }


  // =========================
  // DOCUMENTO
  // =========================

  void _onDocumentChanged(
    String value,
  ) {
    _documentDebounce?.cancel();

    setState(() {
      _documentAvailable =
          null;
    });

    final document =
        value.trim();

    // El documento es opcional.
    if (document.isEmpty) {
      return;
    }

    if (document.length >
        50) {
      return;
    }

    _documentDebounce =
        Timer(
      const Duration(
        milliseconds:
            600,
      ),
      () {
        _checkDocument(
          document,
        );
      },
    );
  }


  Future<void> _checkDocument(
    String document,
  ) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isCheckingDocument =
          true;
    });

    try {
      final result =
          await AuthService.checkDocument(
        document,
      );

      if (!mounted) {
        return;
      }

      final currentText =
          _documentController.text
              .trim();

      final checkedDocument =
          result['document_number']
              ?.toString()
              .trim();

      if (currentText !=
          checkedDocument) {
        return;
      }

      setState(() {
        _documentAvailable =
            result['available'] ==
                true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _documentAvailable =
            null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingDocument =
              false;
        });
      }
    }
  }


  // =========================
  // FECHA
  // =========================

  int _daysInSelectedMonth() {
    if (_selectedMonth ==
            null ||
        _selectedYear ==
            null) {
      return 31;
    }


    return DateTime(
      _selectedYear!,
      _selectedMonth! + 1,
      0,
    ).day;
  }


  void _validateSelectedDay() {
    if (_selectedDay ==
        null) {
      return;
    }


    final maxDays =
        _daysInSelectedMonth();


    if (_selectedDay! >
        maxDays) {
      _selectedDay =
          maxDays;
    }
  }


  DateTime?
      _buildDateOfBirth() {
    if (_selectedDay ==
            null ||
        _selectedMonth ==
            null ||
        _selectedYear ==
            null) {
      return null;
    }


    return DateTime(
      _selectedYear!,
      _selectedMonth!,
      _selectedDay!,
    );
  }


  // =========================
  // COMPLETAR
  // =========================

  Future<void>
      _completeProfile() async {
    FocusScope.of(context)
        .unfocus();


    if (!_formKey.currentState!
        .validate()) {
      return;
    }


    if (_usernameAvailable !=
        true) {
      _showError(
        'Elige un nombre de usuario disponible',
      );

      return;
    }


    final document =
        _documentController.text.trim();

    if (document.isNotEmpty &&
        _documentAvailable !=
            true) {
      _showError(
        'Ingresa un documento disponible',
      );

      return;
    }


    final dateOfBirth =
        _buildDateOfBirth();


    if (dateOfBirth ==
        null) {
      _showError(
        'Selecciona tu fecha de nacimiento',
      );

      return;
    }


    if (_selectedAvatarUrl ==
        null) {
      _showError(
        'Selecciona un avatar',
      );

      return;
    }


    setState(() {
      _isLoading =
          true;
    });


    try {
      await AuthService.completeProfile(
        username:
            _usernameController.text,

        dateOfBirth:
            dateOfBirth,

        phone:
            _phoneController.text,

        documentNumber:
            _documentController.text,

        address:
            _addressController.text,

        photoUrl:
            _selectedAvatarUrl,
      );


      if (!mounted) {
        return;
      }


      Navigator.pushAndRemoveUntil(
        context,

        MaterialPageRoute(
          builder:
              (_) =>
                  const MainNavigationScreen(),
        ),

        (_) =>
            false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }


      String message =
          error.toString();


      if (message.startsWith(
        'Exception: ',
      )) {
        message =
            message.substring(
          'Exception: '.length,
        );
      }


      _showError(
        message,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading =
              false;
        });
      }
    }
  }


  // =========================
  // ERROR
  // =========================

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(
          message,
        ),

        backgroundColor:
            AppColors.error,
      ),
    );
  }


  // =========================
  // UI
  // =========================

  @override
  Widget build(
    BuildContext context,
  ) {
    final firstName =
        widget.user?['first_name']
                ?.toString() ??
            '';


    final email =
        widget.user?['email']
                ?.toString() ??
            '';


    final originalPhotoUrl =
        widget.user?['photo_url']
            ?.toString();


    final currentYear =
        DateTime.now().year;


    final years =
        List<int>.generate(
      100,
      (index) =>
          currentYear -
          index,
    );


    final months =
        const [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];


    final days =
        List<int>.generate(
      _daysInSelectedMonth(),
      (index) =>
          index + 1,
    );


    return Scaffold(
      backgroundColor:
          AppColors.background,

      body:
          SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(
            horizontal:
                24,

            vertical:
                30,
          ),

          child:
              Form(
            key:
                _formKey,

            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,

              children: [
                // =========================
                // FOTO PRINCIPAL
                // =========================

                Center(
                  child:
                      Container(
                    width:
                        106,

                    height:
                        106,

                    clipBehavior:
                        Clip.antiAlias,

                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,

                      color:
                          AppColors.surface,

                      border:
                          Border.all(
                        color:
                            AppColors.primary,

                        width:
                            3,
                      ),

                      boxShadow:
                          [
                        BoxShadow(
                          color:
                              AppColors.primary
                                  .withValues(
                            alpha:
                                0.18,
                          ),

                          blurRadius:
                              22,

                          spreadRadius:
                              2,
                        ),
                      ],
                    ),

                    child:
                        _selectedAvatarUrl !=
                                    null &&
                                _selectedAvatarUrl!
                                    .isNotEmpty
                            ? Image.network(
                                _selectedAvatarUrl!,

                                fit:
                                    BoxFit.cover,

                                errorBuilder:
                                    (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return const Icon(
                                    Icons
                                        .person_rounded,

                                    size:
                                        54,

                                    color:
                                        AppColors.textSecondary,
                                  );
                                },
                              )
                            : const Icon(
                                Icons
                                    .person_rounded,

                                size:
                                    54,

                                color:
                                    AppColors.textSecondary,
                              ),
                  ),
                ),


                const SizedBox(
                  height:
                      22,
                ),


                const Text(
                  'Completa tu perfil',

                  textAlign:
                      TextAlign.center,

                  style:
                      TextStyle(
                    color:
                        AppColors.textPrimary,

                    fontSize:
                        28,

                    fontWeight:
                        FontWeight.w800,
                  ),
                ),


                const SizedBox(
                  height:
                      8,
                ),


                Text(
                  firstName.isNotEmpty
                      ? 'Hola $firstName, personaliza tu perfil.'
                      : 'Personaliza tu perfil para comenzar.',

                  textAlign:
                      TextAlign.center,

                  style:
                      const TextStyle(
                    color:
                        AppColors.textSecondary,

                    fontSize:
                        14,
                  ),
                ),


                if (email.isNotEmpty) ...[
                  const SizedBox(
                    height:
                        5,
                  ),

                  Text(
                    email,

                    textAlign:
                        TextAlign.center,

                    style:
                        const TextStyle(
                      color:
                          AppColors.textSecondary,

                      fontSize:
                          13,
                    ),
                  ),
                ],


                const SizedBox(
                  height:
                      34,
                ),


                // =========================
                // AVATAR
                // =========================

                const Text(
                  'Elige tu avatar',

                  style:
                      TextStyle(
                    color:
                        AppColors.textPrimary,

                    fontSize:
                        16,

                    fontWeight:
                        FontWeight.w700,
                  ),
                ),


                const SizedBox(
                  height:
                      6,
                ),


                const Text(
                  'Puedes cambiarlo más adelante.',

                  style:
                      TextStyle(
                    color:
                        AppColors.textSecondary,

                    fontSize:
                        12,
                  ),
                ),


                const SizedBox(
                  height:
                      16,
                ),


                GridView.builder(
                  shrinkWrap:
                      true,

                  physics:
                      const NeverScrollableScrollPhysics(),

                  itemCount:
                      _avatars.length,

                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        5,

                    crossAxisSpacing:
                        12,

                    mainAxisSpacing:
                        14,

                    childAspectRatio:
                        1,
                  ),

                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final avatar =
                        _avatars[index];


                    final selected =
                        _selectedAvatarUrl ==
                            avatar;


                    return GestureDetector(
                      onTap:
                          _isLoading
                              ? null
                              : () {
                                  _selectAvatar(
                                    avatar,
                                  );
                                },

                      child:
                          AnimatedContainer(
                        duration:
                            const Duration(
                          milliseconds:
                              180,
                        ),

                        padding:
                            EdgeInsets.all(
                          selected
                              ? 3
                              : 1.5,
                        ),

                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,

                          color:
                              selected
                                  ? AppColors.primary
                                  : AppColors.surface,

                          border:
                              Border.all(
                            color:
                                selected
                                    ? AppColors.primary
                                    : AppColors.surface,

                            width:
                                selected
                                    ? 2
                                    : 1,
                          ),
                        ),

                        child:
                            ClipOval(
                          child:
                              Image.network(
                            avatar,

                            fit:
                                BoxFit.cover,

                            loadingBuilder:
                                (
                              context,
                              child,
                              progress,
                            ) {
                              if (progress ==
                                  null) {
                                return child;
                              }

                              return Container(
                                color:
                                    AppColors.surface,

                                alignment:
                                    Alignment.center,

                                child:
                                    const SizedBox(
                                  width:
                                      18,

                                  height:
                                      18,

                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,

                                    color:
                                        AppColors.primary,
                                  ),
                                ),
                              );
                            },

                            errorBuilder:
                                (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return Container(
                                color:
                                    AppColors.surface,

                                alignment:
                                    Alignment.center,

                                child:
                                    const Icon(
                                  Icons
                                      .person_rounded,

                                  color:
                                      AppColors.textSecondary,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),


                // =========================
                // FOTO GOOGLE ACTUAL
                // =========================

                if (originalPhotoUrl !=
                        null &&
                    originalPhotoUrl
                        .isNotEmpty &&
                    !_avatars.contains(
                      originalPhotoUrl,
                    )) ...[
                  const SizedBox(
                    height:
                        18,
                  ),


                  OutlinedButton.icon(
                    onPressed:
                        _isLoading
                            ? null
                            : () {
                                _selectAvatar(
                                  originalPhotoUrl,
                                );
                              },

                    icon:
                        const Icon(
                      Icons
                          .account_circle_outlined,
                    ),

                    label:
                        const Text(
                      'Usar mi foto actual',
                    ),

                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor:
                          AppColors.textPrimary,

                      side:
                          BorderSide(
                        color:
                            _selectedAvatarUrl ==
                                    originalPhotoUrl
                                ? AppColors.primary
                                : AppColors.textSecondary
                                    .withValues(
                                  alpha:
                                      0.35,
                                ),
                      ),

                      padding:
                          const EdgeInsets.symmetric(
                        vertical:
                            14,
                      ),

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                    ),
                  ),
                ],


                const SizedBox(
                  height:
                      34,
                ),


                // =========================
                // USERNAME
                // =========================

                const Text(
                  'Nombre de usuario',

                  style:
                      TextStyle(
                    color:
                        AppColors.textPrimary,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),


                const SizedBox(
                  height:
                      8,
                ),


                TextFormField(
                  controller:
                      _usernameController,

                  enabled:
                      !_isLoading,

                  autocorrect:
                      false,

                  enableSuggestions:
                      false,

                  onChanged:
                      _onUsernameChanged,

                  style:
                      const TextStyle(
                    color:
                        AppColors.textPrimary,
                  ),

                  validator:
                      (value) {
                    final username =
                        value
                                ?.trim() ??
                            '';


                    if (username.isEmpty) {
                      return 'Ingresa un nombre de usuario';
                    }


                    if (username.length <
                        3) {
                      return 'Debe tener al menos 3 caracteres';
                    }


                    if (username.length >
                        50) {
                      return 'Máximo 50 caracteres';
                    }


                    if (!RegExp(
                      r'^[a-zA-Z0-9._]+$',
                    ).hasMatch(
                      username,
                    )) {
                      return 'Solo letras, números, punto y _';
                    }


                    return null;
                  },

                  decoration:
                      InputDecoration(
                    hintText:
                        'Ej. mosito_23',

                    hintStyle:
                        const TextStyle(
                      color:
                          AppColors.textSecondary,
                    ),

                    prefixIcon:
                        const Icon(
                      Icons
                          .alternate_email_rounded,

                      color:
                          AppColors.textSecondary,
                    ),

                    suffixIcon:
                        _isCheckingUsername
                            ? const Padding(
                                padding:
                                    EdgeInsets.all(
                                  14,
                                ),

                                child:
                                    SizedBox(
                                  width:
                                      18,

                                  height:
                                      18,

                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,

                                    color:
                                        AppColors.primary,
                                  ),
                                ),
                              )
                            : _usernameAvailable ==
                                    true
                                ? const Icon(
                                    Icons
                                        .check_circle_rounded,

                                    color:
                                        Colors.green,
                                  )
                                : _usernameAvailable ==
                                        false
                                    ? const Icon(
                                        Icons
                                            .cancel_rounded,

                                        color:
                                            AppColors.error,
                                      )
                                    : null,

                    filled:
                        true,

                    fillColor:
                        AppColors.surface,

                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),

                      borderSide:
                          BorderSide.none,
                    ),

                    enabledBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),

                      borderSide:
                          BorderSide.none,
                    ),

                    focusedBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),

                      borderSide:
                          const BorderSide(
                        color:
                            AppColors.primary,

                        width:
                            1.4,
                      ),
                    ),
                  ),
                ),


                if (_usernameAvailable ==
                    true)
                  const Padding(
                    padding:
                        EdgeInsets.only(
                      top:
                          8,
                    ),

                    child:
                        Text(
                      '✓ Nombre disponible',

                      style:
                          TextStyle(
                        color:
                            Colors.green,

                        fontSize:
                            13,
                      ),
                    ),
                  ),


                if (_usernameAvailable ==
                    false) ...[
                  const Padding(
                    padding:
                        EdgeInsets.only(
                      top:
                          8,
                    ),

                    child:
                        Text(
                      'Ese nombre ya está ocupado',

                      style:
                          TextStyle(
                        color:
                            AppColors.error,

                        fontSize:
                            13,
                      ),
                    ),
                  ),


                  if (_usernameSuggestions
                      .isNotEmpty) ...[
                    const SizedBox(
                      height:
                          10,
                    ),


                    Wrap(
                      spacing:
                          8,

                      runSpacing:
                          8,

                      children:
                          _usernameSuggestions
                              .map(
                                (
                                  username,
                                ) =>
                                    ActionChip(
                                  label:
                                      Text(
                                    '@$username',
                                  ),

                                  onPressed:
                                      () {
                                    _useSuggestion(
                                      username,
                                    );
                                  },
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ],


                const SizedBox(
                  height:
                      28,
                ),


                // =========================
                // FECHA
                // =========================

                const Text(
                  'Fecha de nacimiento',

                  style:
                      TextStyle(
                    color:
                        AppColors.textPrimary,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),


                const SizedBox(
                  height:
                      8,
                ),


                Row(
                  children: [
                    Expanded(
                      child:
                          _dateDropdown<int>(
                        hint:
                            'Día',

                        value:
                            _selectedDay,

                        items:
                            days,

                        labelBuilder:
                            (day) =>
                                day.toString(),

                        onChanged:
                            (value) {
                          setState(() {
                            _selectedDay =
                                value;
                          });
                        },
                      ),
                    ),


                    const SizedBox(
                      width:
                          8,
                    ),


                    Expanded(
                      flex:
                          2,

                      child:
                          _dateDropdown<int>(
                        hint:
                            'Mes',

                        value:
                            _selectedMonth,

                        items:
                            List<int>.generate(
                          12,
                          (index) =>
                              index +
                              1,
                        ),

                        labelBuilder:
                            (month) =>
                                months[
                                  month -
                                      1
                                ],

                        onChanged:
                            (value) {
                          setState(() {
                            _selectedMonth =
                                value;

                            _validateSelectedDay();
                          });
                        },
                      ),
                    ),


                    const SizedBox(
                      width:
                          8,
                    ),


                    Expanded(
                      flex:
                          2,

                      child:
                          _dateDropdown<int>(
                        hint:
                            'Año',

                        value:
                            _selectedYear,

                        items:
                            years,

                        labelBuilder:
                            (year) =>
                                year.toString(),

                        onChanged:
                            (value) {
                          setState(() {
                            _selectedYear =
                                value;

                            _validateSelectedDay();
                          });
                        },
                      ),
                    ),
                  ],
                ),


                const SizedBox(
                  height:
                      34,
                ),


                // =========================
                // INFORMACIÓN PERSONAL
                // =========================

                const Text(
                  'Información personal',

                  style:
                      TextStyle(
                    color:
                        AppColors.textPrimary,

                    fontSize:
                        16,

                    fontWeight:
                        FontWeight.w700,
                  ),
                ),


                const SizedBox(
                  height:
                      6,
                ),


                const Text(
                  'Estos datos son opcionales y puedes cambiarlos después.',

                  style:
                      TextStyle(
                    color:
                        AppColors.textSecondary,

                    fontSize:
                        12,
                  ),
                ),


                const SizedBox(
                  height:
                      16,
                ),


                TextFormField(
                  controller:
                      _phoneController,

                  enabled:
                      !_isLoading,

                  keyboardType:
                      TextInputType.phone,

                  textInputAction:
                      TextInputAction.next,

                  style:
                      const TextStyle(
                    color:
                        AppColors.textPrimary,
                  ),

                  decoration:
                      _profileInputDecoration(
                    hint:
                        'Teléfono',

                    icon:
                        Icons.phone_outlined,
                  ),
                ),


                const SizedBox(
                  height:
                      14,
                ),


                TextFormField(
                  controller:
                      _documentController,

                  enabled:
                      !_isLoading,

                  textInputAction:
                      TextInputAction.next,

                  autocorrect:
                      false,

                  onChanged:
                      _onDocumentChanged,

                  validator:
                      (value) {
                    final document =
                        value?.trim() ??
                            '';

                    if (document.length >
                        50) {
                      return 'Máximo 50 caracteres';
                    }

                    if (document.isNotEmpty &&
                        _documentAvailable ==
                            false) {
                      return 'Este documento ya está registrado';
                    }

                    return null;
                  },

                  style:
                      const TextStyle(
                    color:
                        AppColors.textPrimary,
                  ),

                  decoration:
                      _profileInputDecoration(
                    hint:
                        'Número de documento',

                    icon:
                        Icons.badge_outlined,

                    suffixIcon:
                        _isCheckingDocument
                            ? const Padding(
                                padding:
                                    EdgeInsets.all(
                                  14,
                                ),

                                child:
                                    SizedBox(
                                  width:
                                      18,

                                  height:
                                      18,

                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,

                                    color:
                                        AppColors.primary,
                                  ),
                                ),
                              )
                            : _documentController.text.trim().isEmpty
                                ? null
                                : _documentAvailable ==
                                        true
                                    ? const Icon(
                                        Icons.check_circle_rounded,

                                        color:
                                            Colors.green,
                                      )
                                    : _documentAvailable ==
                                            false
                                        ? const Icon(
                                            Icons.cancel_rounded,

                                            color:
                                                AppColors.error,
                                          )
                                        : null,
                  ),
                ),


                if (_documentController.text
                        .trim()
                        .isNotEmpty &&
                    _documentAvailable ==
                        true)
                  const Padding(
                    padding:
                        EdgeInsets.only(
                      top:
                          8,
                    ),

                    child:
                        Text(
                      '✓ Documento disponible',

                      style:
                          TextStyle(
                        color:
                            Colors.green,

                        fontSize:
                            13,
                      ),
                    ),
                  ),


                if (_documentController.text
                        .trim()
                        .isNotEmpty &&
                    _documentAvailable ==
                        false)
                  const Padding(
                    padding:
                        EdgeInsets.only(
                      top:
                          8,
                    ),

                    child:
                        Text(
                      'Este documento ya está registrado',

                      style:
                          TextStyle(
                        color:
                            AppColors.error,

                        fontSize:
                            13,
                      ),
                    ),
                  ),


                const SizedBox(
                  height:
                      14,
                ),


                TextFormField(
                  controller:
                      _addressController,

                  enabled:
                      !_isLoading,

                  textCapitalization:
                      TextCapitalization.sentences,

                  textInputAction:
                      TextInputAction.done,

                  minLines:
                      1,

                  maxLines:
                      3,

                  style:
                      const TextStyle(
                    color:
                        AppColors.textPrimary,
                  ),

                  decoration:
                      _profileInputDecoration(
                    hint:
                        'Dirección',

                    icon:
                        Icons.location_on_outlined,
                  ),
                ),


                const SizedBox(
                  height:
                      34,
                ),


                SizedBox(
                  height:
                      54,

                  child:
                      ElevatedButton(
                    onPressed:
                        _isLoading ||
                                _isCheckingUsername ||
                                _isCheckingDocument ||
                                _usernameAvailable !=
                                    true ||
                                (_documentController.text
                                        .trim()
                                        .isNotEmpty &&
                                    _documentAvailable !=
                                        true)
                            ? null
                            : _completeProfile,

                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.primary,

                      foregroundColor:
                          Colors.white,

                      disabledBackgroundColor:
                          AppColors.primary
                              .withValues(
                        alpha:
                            0.45,
                      ),

                      elevation:
                          0,

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                    ),

                    child:
                        _isLoading
                            ? const SizedBox(
                                width:
                                    22,

                                height:
                                    22,

                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2.5,

                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Text(
                                'Continuar',

                                style:
                                    TextStyle(
                                  fontSize:
                                      16,

                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                  ),
                ),


                const SizedBox(
                  height:
                      16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // =========================
  // INPUT PERFIL
  // =========================

  InputDecoration _profileInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText:
          hint,

      hintStyle:
          const TextStyle(
        color:
            AppColors.textSecondary,
      ),

      prefixIcon:
          Icon(
        icon,

        color:
            AppColors.textSecondary,
      ),

      suffixIcon:
          suffixIcon,

      filled:
          true,

      fillColor:
          AppColors.surface,

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal:
            16,

        vertical:
            16,
      ),

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),

        borderSide:
            BorderSide.none,
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),

        borderSide:
            BorderSide.none,
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),

        borderSide:
            const BorderSide(
          color:
              AppColors.primary,

          width:
              1.4,
        ),
      ),
    );
  }


  // =========================
  // DROPDOWN
  // =========================

  Widget _dateDropdown<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T)
        labelBuilder,
    required ValueChanged<T?>
        onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue:
          value,

      isExpanded:
          true,

      dropdownColor:
          AppColors.surface,

      style:
          const TextStyle(
        color:
            AppColors.textPrimary,
      ),

      decoration:
          InputDecoration(
        filled:
            true,

        fillColor:
            AppColors.surface,

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal:
              12,

          vertical:
              16,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),

          borderSide:
              BorderSide.none,
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),

          borderSide:
              BorderSide.none,
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),

          borderSide:
              const BorderSide(
            color:
                AppColors.primary,

            width:
                1.4,
          ),
        ),
      ),

      hint:
          Text(
        hint,

        style:
            const TextStyle(
          color:
              AppColors.textSecondary,

          fontSize:
              13,
        ),
      ),

      items:
          items
              .map(
                (
                  item,
                ) =>
                    DropdownMenuItem<T>(
                  value:
                      item,

                  child:
                      Text(
                    labelBuilder(
                      item,
                    ),
                  ),
                ),
              )
              .toList(),

      onChanged:
          _isLoading
              ? null
              : onChanged,
    );
  }
}