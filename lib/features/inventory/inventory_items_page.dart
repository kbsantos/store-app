import 'package:flutter/material.dart';
import '../../core/auth/store_management_auth.dart';

class InventoryItemsPage extends StatefulWidget {
  const InventoryItemsPage({super.key});
  @override State<InventoryItemsPage> createState() => _InventoryItemsPageState();
}

class _InventoryItemsPageState extends State<InventoryItemsPage> {
  final _auth = const StoreManagementAuth();
  final _search = TextEditingController();
  List<Map<String,dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  bool get _canEdit => _auth.canManageInventory;

  @override void initState(){ super.initState(); _load(); }
  @override void dispose(){ _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState((){_loading=true;_error=null;});
    try {
      final result=await _auth.client.rpc('get_store_inventory_items');
      final rows=(result as List?) ?? const [];
      if(!mounted)return;
      setState((){_items=rows.map((r)=>Map<String,dynamic>.from(r as Map)).toList();_loading=false;});
    } catch(e){if(!mounted)return;setState((){_loading=false;_error=e.toString();});}
  }

  List<Map<String,dynamic>> get _filtered {
    final q=_search.text.trim().toLowerCase();
    if(q.isEmpty)return _items;
    return _items.where((i)=>['name','category','unit'].any((k)=>(i[k]?.toString().toLowerCase()??'').contains(q))).toList();
  }

  Future<void> _edit([Map<String,dynamic>? item]) async {
    if(!_canEdit)return;
    final changed=await showDialog<bool>(context:context,builder:(_)=>_InventoryDialog(item:item));
    if(changed==true)_load();
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor:const Color(0xFFF5F2ED),
      appBar:AppBar(title:const Text('INVENTORY ITEMS'),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh),tooltip:'Refresh')]),
      floatingActionButton:_canEdit?FloatingActionButton.extended(onPressed:()=>_edit(),icon:const Icon(Icons.add),label:const Text('ADD ITEM')):null,
      body:ListView(padding:const EdgeInsets.all(24),children:[
        const Text('INVENTORY ITEMS',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),
        const SizedBox(height:6),Text('Store ${_auth.storeId}',style:const TextStyle(color:Colors.black54)),
        const SizedBox(height:20),
        TextField(controller:_search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'Search inventory items',prefixIcon:Icon(Icons.search),border:OutlineInputBorder())),
        const SizedBox(height:16),
        if(!_canEdit)const Card(child:ListTile(leading:Icon(Icons.visibility_outlined),title:Text('Read-only access'),subtitle:Text('Owner, manager or admin access is required to add or edit inventory items.'))),
        if(_loading)const Padding(padding:EdgeInsets.all(32),child:Center(child:CircularProgressIndicator()))
        else if(_error!=null)Card(child:ListTile(leading:const Icon(Icons.error_outline),title:const Text('Unable to load inventory items'),subtitle:Text('$_error'),trailing:IconButton(onPressed:_load,icon:const Icon(Icons.refresh))))
        else if(_filtered.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(32),child:Column(children:[Icon(Icons.inventory_2_outlined,size:48),SizedBox(height:10),Text('No inventory items found',style:TextStyle(fontWeight:FontWeight.w800)),SizedBox(height:4),Text('Add ingredients, packaging and other stock items used by the store.')])))
        else ..._filtered.map(_card),
        const SizedBox(height:80),
      ]),
    );
  }

  Widget _card(Map<String,dynamic> i){
    final active=i['is_active']==true;
    final category=i['category']?.toString().trim()??'';
    final unit=i['unit']?.toString().trim()??'';
    return Card(margin:const EdgeInsets.only(bottom:10),child:ListTile(
      contentPadding:const EdgeInsets.symmetric(horizontal:18,vertical:8),
      leading:CircleAvatar(child:Icon(active?Icons.inventory_2_outlined:Icons.inventory_2)),
      title:Text(i['name']?.toString()??'',style:const TextStyle(fontWeight:FontWeight.w800)),
      subtitle:Text([if(category.isNotEmpty)category,if(unit.isNotEmpty)'Unit: $unit','Reorder: ${_num(i['reorder_level'])}'].join(' • ')),
      trailing:Wrap(crossAxisAlignment:WrapCrossAlignment.center,children:[Chip(label:Text(active?'ACTIVE':'INACTIVE')),if(_canEdit)IconButton(onPressed:()=>_edit(i),icon:const Icon(Icons.edit_outlined),tooltip:'Edit')]),
    ));
  }
  String _num(dynamic v){final n=v is num?v:num.tryParse(v?.toString()??'');if(n==null)return'0';return n%1==0?n.toInt().toString():n.toString();}
}

class _InventoryDialog extends StatefulWidget {
  final Map<String,dynamic>? item;
  const _InventoryDialog({this.item});
  @override State<_InventoryDialog> createState()=>_InventoryDialogState();
}
class _InventoryDialogState extends State<_InventoryDialog>{
  final _auth=const StoreManagementAuth();final _form=GlobalKey<FormState>();
  late final TextEditingController _name,_category,_unit,_reorder;late bool _active;bool _saving=false;
  bool get _editing=>widget.item!=null;
  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _name = TextEditingController(
      text: i == null ? '' : i['name']?.toString() ?? '',
    );
    _category = TextEditingController(
      text: i == null ? '' : i['category']?.toString() ?? '',
    );
    _unit = TextEditingController(
      text: i == null ? '' : i['unit']?.toString() ?? '',
    );
    _reorder = TextEditingController(
      text: i == null ? '0' : _n(i['reorder_level']) ?? '0',
    );
    _active = i == null ? true : i['is_active'] != false;
  }
  @override void dispose(){_name.dispose();_category.dispose();_unit.dispose();_reorder.dispose();super.dispose();}
  String? _n(dynamic v){if(v==null)return null;final n=v is num?v:num.tryParse(v.toString());if(n==null)return null;return n%1==0?n.toInt().toString():n.toString();}
  Future<void> _save()async{if(!_form.currentState!.validate())return;final reorder=num.tryParse(_reorder.text.trim());if(reorder==null||reorder<0)return;setState(()=>_saving=true);try{if(_editing){await _auth.client.rpc('update_store_inventory_item',params:{'p_id':widget.item!['id'],'p_name':_name.text,'p_category':_category.text,'p_unit':_unit.text,'p_reorder_level':reorder,'p_is_active':_active});}else{await _auth.client.rpc('create_store_inventory_item',params:{'p_name':_name.text,'p_category':_category.text,'p_unit':_unit.text,'p_reorder_level':reorder,'p_is_active':_active});}if(mounted)Navigator.of(context).pop(true);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Unable to save inventory item: $e')));}finally{if(mounted)setState(()=>_saving=false);}}
  @override Widget build(BuildContext context)=>AlertDialog(title:Text(_editing?'EDIT INVENTORY ITEM':'ADD INVENTORY ITEM'),content:SizedBox(width:480,child:Form(key:_form,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextFormField(controller:_name,decoration:const InputDecoration(labelText:'Item name'),validator:(v)=>v==null||v.trim().isEmpty?'Required':null),const SizedBox(height:12),
    TextFormField(controller:_category,decoration:const InputDecoration(labelText:'Category (optional)')),const SizedBox(height:12),
    TextFormField(controller:_unit,decoration:const InputDecoration(labelText:'Unit (e.g. kg, L, pcs)'),validator:(v)=>v==null||v.trim().isEmpty?'Required':null),const SizedBox(height:12),
    TextFormField(controller:_reorder,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Reorder level'),validator:(v)=>num.tryParse(v?.trim()??'')==null?'Enter a number':null),
    SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Active'),value:_active,onChanged:(v)=>setState(()=>_active=v)),
  ])))),actions:[TextButton(onPressed:_saving?null:()=>Navigator.of(context).pop(),child:const Text('CANCEL')),FilledButton(onPressed:_saving?null:_save,child:Text(_saving?'SAVING...':'SAVE'))]);
}
