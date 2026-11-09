import 'package:flutter/material.dart';

// Estética monocromática inspirada en tiendas de moda, aplicada solo a devoluciones.
class ReturnStyle {
  static const ink=Color(0xFF141414);
  static const paper=Color(0xFFFFFFFF);
  static const canvas=Color(0xFFF6F6F6);
  static const grey=Color(0xFF737373);
  static const line=Color(0xFFE5E5E5);
  static const accent=Color(0xFFBD3351);
  static AppBar appBar(String title)=>AppBar(backgroundColor:paper,foregroundColor:ink,surfaceTintColor:Colors.transparent,elevation:0,title:Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800,letterSpacing:.2)));
  static Widget section({required Widget child})=>Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:paper,border:Border.all(color:line),borderRadius:BorderRadius.circular(8)),child:child);
  static Widget button(String label,VoidCallback? onPressed,{bool outline=false})=>SizedBox(width:double.infinity,height:48,child:outline?OutlinedButton(onPressed:onPressed,style:OutlinedButton.styleFrom(foregroundColor:ink,side:const BorderSide(color:ink),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(4))),child:Text(label,style:const TextStyle(fontWeight:FontWeight.bold))):FilledButton(onPressed:onPressed,style:FilledButton.styleFrom(backgroundColor:ink,foregroundColor:paper,disabledBackgroundColor:line,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(4))),child:Text(label,style:const TextStyle(fontWeight:FontWeight.bold))));
  static Widget label(String value)=>Text(value,style:const TextStyle(color:grey,fontSize:12));
}
