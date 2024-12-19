import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chat/chatroom_list_screen.dart';

class RoomCreateScreen extends StatefulWidget{
  @override
  _RoomCreateScreenState createState() => _RoomCreateScreenState();
}

class _RoomCreateScreenState extends State<RoomCreateScreen>{
  final TextEditingController _roomNameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose(){
    _roomNameController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async{
    final roomName = _roomNameController.text.trim();
    if(roomName.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ルーム名を入力してください')),
      );
      return;
    }

    try{
      final currentUser = _auth.currentUser;
      if(currentUser == null){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログインしてください')),
        );
        return;
      }

      final roomId = Uuid().v4();
      await _firestore.collection('chatRooms').doc(roomId).set({
        'name': roomName,
        'createdAt': FieldValue.serverTimestamp(),
        'participants': [currentUser.uid],
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ルームが作成されました')),
      );

      //元の画面に戻る
      Navigator.pop(context);
    } catch (e){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ルームの作成に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Room'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed:(){
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children:[
            TextField(
              controller: _roomNameController,
              decoration: const InputDecoration(
                labelText: 'ルーム名',
                hintText: 'ルーム名を入力してください',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createRoom,
              child: const Text('ルームを作成'),
            ),
          ],
        ),
      ),
    );
  }
}