import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';

class ChatScreen extends StatefulWidget{
  final String roomId; // チャットルームID
  const ChatScreen({super.key, required this.roomId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>{
  final List<types.Message> _messages = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  types.User? _user; // 修正: 初期化時はnull
  int _participantCount = 0;
  final TextEditingController _memberController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _participantsSubscription;

  @override
  void initState(){
    super.initState();
    _initializeUser();
    _loadMessages();
    _loadParticipantCount();
  }

  @override
  void dispose(){
    _messageController.dispose();
    _memberController.dispose();
    _messagesSubscription?.cancel();
    _participantsSubscription?.cancel();
    super.dispose();
  }

  void _initializeUser(){
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      // ログインしていない場合のエラー処理
      WidgetsBinding.instance.addPostFrameCallback((_){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログイン情報がありません。')),
        );
        Navigator.pop(context);
      });
    } else{
      setState((){
        _user = types.User(
          id: currentUser.uid,
          firstName: currentUser.displayName ?? 'User',
        );
      });
    }
  }

  void _loadMessages(){
    try {
      // Firestoreのmessagesコレクションをリアルタイムで取得
      _messagesSubscription = _firestore
          .collection('chatRooms')
          .doc(widget.roomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot){
        if (!mounted) return;

        final messages = snapshot.docs.map((doc){
          final data = doc.data();
          return types.TextMessage(
            id: doc.id,
            author: types.User(
              id: data['senderId'],
              firstName: data['senderName'] ?? 'User',
            ),
            text: data['content'],
            createdAt:
                (data['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ??
                    DateTime.now().millisecondsSinceEpoch,
          );
        }).toList();

        if(mounted){
          setState((){
            _messages
              ..clear()
              ..addAll(messages);
          });
        }
      }, onError: (error){
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('メッセージの読み込みに失敗しました'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: '再読み込み',
              textColor: Colors.white,
              onPressed: _loadMessages,
            ),
          ),
        );
        print('Error loading messages: $error');
      });
    } catch (e) {
      if(!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラーが発生しました'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error in _loadMessages: $e');
    }
  }

  void _loadParticipantCount(){
    _participantsSubscription = _firestore
        .collection('chatRooms')
        .doc(widget.roomId)
        .snapshots()
        .listen((doc){
      if(!mounted) return;

      if(doc.exists){
        final data = doc.data()!;
        final participants = data['participants'] as List<dynamic>? ?? [];
        setState((){
          _participantCount = participants.length;
        });
      }
    });
  }

  void _handleSendPressed(types.PartialText message) async{
    if(_user == null || !mounted) return;

    if(message.text.trim().isEmpty) {
      return;
    }

    final textMessage = types.TextMessage(
      author: _user!,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
    );

    try {
      // Firestoreにメッセージを保存
      final messageRef = await _firestore
          .collection('chatRooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'senderId': _user!.id,
        'content': message.text,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
      });

      // チャットルームの最終メッセージと更新時刻を更新
      await _firestore.collection('chatRooms').doc(widget.roomId).update({
        'lastMessage': message.text,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 手動でメッセージを追加しない
      // Firestoreのリアルタイムリスナーがメッセージを追加する
    }catch(e) {
      if(!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('メッセージの送信に失敗しました。もう一度お試しください。'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: '再試行',
            textColor: Colors.white,
            onPressed: () {
              _handleSendPressed(message);
            },
          ),
        ),
      );
      print('Error sending message: $e');
    }
  }

  // メンバー追加のダイアログを表示
  void _showAddMemberDialog(){
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('メンバー追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _memberController,
                decoration: const InputDecoration(
                  labelText: 'ユーザーID',
                  hintText: 'メンバーのユーザーIDを入力',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: (){
                _addMember(_memberController.text);
                Navigator.pop(context);
              },
              child: const Text('追加'),
            ),
          ],
        );
      },
    );
  }

  // メンバーを追加する関数
  Future<void> _addMember(String userId) async{
    if(userId.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザーIDを入力してください')),
      );
      return;
    }

    try{
      // ユーザーが存在するかどうかを確認するクエリ
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: userId) // 'uid'フィールドで検索
          .get();

      // デバッグログを追加
      print('User query result: ${userQuery.docs}');

      if(userQuery.docs.isEmpty) {
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('指定されたユーザーが存在しません')),
        );
        return;
      }

      // ルーム情報を取得
      final roomDoc =
          await _firestore.collection('chatRooms').doc(widget.roomId).get();
      final List<dynamic> currentParticipants =
          roomDoc.data()?['participants'] ?? [];

      if(currentParticipants.contains(userId)) {
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('このユーザーは既にメンバーです')),
        );
        return;
      }

      // メンバーを追加
      await _firestore.collection('chatRooms').doc(widget.roomId).update({
        'participants': FieldValue.arrayUnion([userId]),
        'hasNewMember': true,
        'lastInvitedAt': FieldValue.serverTimestamp(),
      });

      // システムメッセージを追加
      final userData = userQuery.docs.first.data();
      await _firestore
          .collection('chatRooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'content': '${userData['name'] ?? userId}さんが招待されました',
        'senderId': 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'system',
      });

      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メンバーを追加しました')),
      );
      _memberController.clear();
    }catch(e) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
      print('メンバー追加エラー: $e');
    }
  }

  // メンバーリストを表示するモーダル
  void _showMemberList() async{
    final roomDoc =
        await _firestore.collection('chatRooms').doc(widget.roomId).get();
    final List<dynamic> participants = roomDoc.data()?['participants'] ?? [];

    if(!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context){
        return AlertDialog(
          title: const Text('メンバーリスト'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: participants.length,
              itemBuilder: (context, index){
                return ListTile(
                  title: Text(participants[index]),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context){
    if (_user == null){
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        title: Text(
          'Chat Room ($_participantCount 名参加)',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.black),
            onPressed: _showAddMemberDialog,
          ),
          IconButton(
            icon: Icon(Icons.list, color: Colors.black),
            onPressed: _showMemberList,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Chat(
              messages: _messages,
              onSendPressed: _handleSendPressed,
              user: _user!,
              customBottomWidget: _buildCustomInputBar(),
              showUserAvatars: true,
            ),
          ),
        ],
      ),
    );
  }

  // LINE風の入力バーを構築
  Widget _buildCustomInputBar(){
    return Container(
      height: 80,
      alignment: Alignment.topCenter,
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: Colors.grey),
            onPressed: () {
              // 追加機能の実装（画像送信など）
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'メッセージを入力',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
              ),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  _handleSendPressed(types.PartialText(text: text));
                  _messageController.clear();
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: Colors.blue),
            onPressed: () {
              final text = _messageController.text;
              if (text.trim().isNotEmpty) {
                _handleSendPressed(types.PartialText(text: text));
                _messageController.clear();
                FocusScope.of(context).unfocus(); // キーボードを閉じる
              }
            },
          ),
        ],
      ),
    );
  }
}