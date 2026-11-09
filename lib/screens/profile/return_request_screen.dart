import 'package:flutter/material.dart';
import '../../models/purchase_order.dart';
import '../../models/return_request.dart';
import '../../services/return_service.dart';
import 'return_detail_screen.dart';
import 'return_style.dart';
import 'return_policy_notice.dart';

class ReturnRequestScreen extends StatefulWidget {
  const ReturnRequestScreen({super.key,required this.order});
  final PurchaseOrder order;
  @override State<ReturnRequestScreen> createState()=>_ReturnRequestScreenState();
}
class _ReturnRequestScreenState extends State<ReturnRequestScreen> {
  ReturnEligibility? eligibility;
  final quantities=<int,int>{};
  final reason=TextEditingController();
  bool loading=true,sending=false;
  String? error;
  @override void initState(){super.initState();_load();}
  @override void dispose(){reason.dispose();super.dispose();}
  Future<void> _load() async {
    setState((){loading=true;error=null;});
    try {final result=await ReturnService.eligibility(widget.order.id);if(mounted)setState(()=>eligibility=result);}
    catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> _submit() async {
    final chosen=Map<int,int>.from(quantities)..removeWhere((k,v)=>v<=0);
    if(chosen.isEmpty || reason.text.trim().length<8 || eligibility?.mayRequest != true)return;
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (dialogContext) => Dialog(
        backgroundColor: ReturnStyle.paper,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.assignment_turned_in_outlined,
                      color: ReturnStyle.ink, size: 23),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('CONFIRMAR DEVOLUCIÓN',
                        style: TextStyle(
                          color: ReturnStyle.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: .2,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: ReturnStyle.line, height: 1),
              const SizedBox(height: 16),
              const Text(
                'Tu solicitud se enviará a la tienda para su revisión. '
                'El reembolso no es automático ni está garantizado hasta su aprobación.',
                style: TextStyle(
                  color: ReturnStyle.grey,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 24),
              ReturnStyle.button(
                'ENVIAR SOLICITUD',
                () => Navigator.of(dialogContext).pop(true),
              ),
              const SizedBox(height: 10),
              ReturnStyle.button(
                'VOLVER',
                () => Navigator.of(dialogContext).pop(false),
                outline: true,
              ),
            ],
          ),
        ),
      ),
    );
    if(confirm!=true || !mounted)return;
    setState(()=>sending=true);
    try {
      // El plazo y las cantidades pueden cambiar mientras el cliente completa el formulario.
      final fresh=await ReturnService.eligibility(widget.order.id);
      if(!mounted)return;
      if(!fresh.mayRequest || chosen.entries.any((entry)=> !fresh.items.any((item)=>item.orderItemId==entry.key && item.availableQuantity>=entry.value))) {
        setState(()=>eligibility=fresh);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('La devolución ya no está disponible o cambió la cantidad permitida.')));
        return;
      }
      final result=await ReturnService.create(orderId:widget.order.id,reason:reason.text,items:chosen);
      if(!mounted)return;
      Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>ReturnDetailScreen(returnId:result.id)));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
    finally{if(mounted)setState(()=>sending=false);}
  }
  @override Widget build(BuildContext context){
    final allowed={for(final line in eligibility?.items ?? <ReturnEligibleItem>[]) line.orderItemId:line};
    final canSend=eligibility?.mayRequest==true && quantities.values.any((v)=>v>0) && reason.text.trim().length>=8 && !sending;
    return Theme(data:ThemeData.light(useMaterial3:true),child:Scaffold(backgroundColor:ReturnStyle.canvas,appBar:ReturnStyle.appBar('SOLICITAR DEVOLUCIÓN'),body:loading?const Center(child:CircularProgressIndicator(color:ReturnStyle.ink)):error!=null?Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[Text(error!,textAlign:TextAlign.center),const SizedBox(height:18),ReturnStyle.button('REINTENTAR',_load)]))):ListView(padding:const EdgeInsets.all(16),children:[
      if(eligibility!=null)...[ReturnPolicyNotice(eligibility:eligibility!),const SizedBox(height:12)],
      ReturnStyle.section(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('SELECCIONA TUS PRENDAS',style:TextStyle(color:ReturnStyle.ink,fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:6),ReturnStyle.label('Pedido ${widget.order.orderCode} · Solo puedes devolver las cantidades disponibles.'),if(eligibility?.reason!=null)...[const SizedBox(height:12),Text(eligibility!.reason!,style:const TextStyle(color:ReturnStyle.accent))],const SizedBox(height:12),...widget.order.items.map((item){final a=allowed[item.id];final max=a?.availableQuantity ?? 0;final current=quantities[item.id] ?? 0;return Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Row(children:[SizedBox(width:58,height:70,child:item.variant.displayImageUrl!=null?Image.network(item.variant.displayImageUrl!,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.checkroom)):const Icon(Icons.checkroom)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item.variant.productName,style:const TextStyle(fontWeight:FontWeight.w700)),ReturnStyle.label('${item.variant.size} · ${item.variant.color}'),ReturnStyle.label('Disponible para devolver: $max'),Text('Bs ${item.unitPrice.toStringAsFixed(2)}',style:const TextStyle(fontWeight:FontWeight.bold))])),Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:current>0?()=>setState(()=>quantities[item.id]=current-1):null,icon:const Icon(Icons.remove_circle_outline)),Text('$current',style:const TextStyle(fontWeight:FontWeight.bold)),IconButton(onPressed:current<max?()=>setState(()=>quantities[item.id]=current+1):null,icon:const Icon(Icons.add_circle_outline))])])) ;})])),
      const SizedBox(height:12),ReturnStyle.section(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('MOTIVO DE LA DEVOLUCIÓN',style:TextStyle(fontWeight:FontWeight.w900)),const SizedBox(height:10),TextField(controller:reason,maxLines:3,maxLength:500,onChanged:(_)=>setState((){}),decoration:const InputDecoration(hintText:'Ej. La talla recibida no corresponde a la solicitada',helperText:'Mínimo 8 caracteres',border:OutlineInputBorder())),const SizedBox(height:8),ReturnStyle.label('El equipo revisará tu solicitud antes de aprobarla.')])),
      const SizedBox(height:16),ReturnStyle.button(sending?'ENVIANDO...':'ENVIAR SOLICITUD',canSend?_submit:null),const SizedBox(height:16)
    ])));
  }
}
