import 'package:chat/chat_screen.dart';
import 'package:chat/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chat/room_create_screen.dart';
import 'package:flutter/services.dart';

class ChatRoomListScreen extends StatefulWidget{
  const ChatRoomListScreen({super.key});

  @override
  State<ChatRoomListScreen> createState() => _ChatRoomListScreenState();
}


class _ChatRoomListScreenState extends State<ChatRoomListScreen>{
  final TextEditingController roomNameController = TextEditingController();
  final TextEditingController participantController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String userId;

  @override
  void initState(){
    super.initState();
    final user = _auth.currentUser;
    if(user == null){
      WidgetsBinding.instance.addPostFrameCallback((_){
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      });
    }else{
      userId = user.uid;
    }
  }

  Future<void> _createRoom(String roomName) async{
    if(roomName.isEmpty) return;

    try{
      final user = _auth.currentUser;
      if (user == null) return;

      final roomRef = await _firestore.collection('chatRooms').add({
        'name': roomName,
        'participants': [user.uid],
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await roomRef.collection('messages').add({
        'senderId': user.uid,
        'content': 'Room created',
        'timestamp': FieldValue.serverTimestamp(),
      });

      roomNameController.clear();
      participantController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ルームが作成されました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating room: $e')),
      );
    }
  }

  Future<void> _addParticipantToRoom(String participantId) async{
    try{
      // Check if the participant ID exists in the authentication system
      final userDoc =
          await _firestore.collection('users').doc(participantId).get();
      if(!userDoc.exists){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('指定されたユーザーIDが存在しません')),
        );
        return;
      }

      final querySnapshot = await _firestore
          .collection('chatRooms')
          .where('participants', arrayContains: _auth.currentUser?.uid)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if(querySnapshot.docs.isNotEmpty){
        final roomDoc = querySnapshot.docs.first;
        print('Room found: ${roomDoc.id}'); // Debug print
        await roomDoc.reference.update({
          'participants': FieldValue.arrayUnion([participantId])
        });
        print('Participant added: $participantId'); // Debug print
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('参加者が正常に追加されました')),
        );
      }else{
        print('No room found for the current user'); // Debug print
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('チャットルームが見つかりません')),
        );
      }
    }
    catch (e){
      print('Error adding participant: $e'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('参加者の追加中にエラーが発生しました: $e')),
      );
    }
  }

  Future<void> _signOut() async{
    try{
      await showDialog(
        context: context,
        builder: (BuildContext context){
          return AlertDialog(
            title: const Text('ログアウト'),
            content: const Text('ログアウトしてもよろしいですか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ログアウト'),
              ),
            ],
          );
        },
      ).then((value) async{
        if(value == true) {
          await _auth.signOut();
          if(!mounted) return;


          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  LoginScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ログアウトに失敗しました: $e')),
      );
    }
  }

  void _showCustomModalSheet(BuildContext context){
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "グループ作成",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: roomNameController,
                    decoration: InputDecoration(
                      hintText: "グループ名",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    "メンバー追加",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: participantController,
                    decoration: InputDecoration(
                      hintText: "ユーザーID",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: (){
                      _createRoom(roomNameController.text);

                      if (participantController.text.isNotEmpty){
                        _addParticipantToRoom(participantController.text);
                      }

                      Navigator.of(context).pop();
                    },
                    child: const Text("Create"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        const curve = Curves.easeInOut;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var fadeAnimation = animation.drive(tween);

        return FadeTransition(
          opacity: fadeAnimation,
          child: child,
        );
      },
    );
  }

  void _showUserInfo(){
    final user = _auth.currentUser;
    if (user != null) {
      showDialog(
        context: context,
        builder: (BuildContext context){
          return AlertDialog(
            title: const Text('ユーザー情報'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'あなたのユーザーID:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(user.uid)),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: (){
                        Clipboard.setData(ClipboardData(text: user.uid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ユーザーIDをコピーしました')),
                        );
                      },
                    ),
                  ],
                ),
              ],
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
  }

  Stream<QuerySnapshot> get _notificationsStream{
    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: _auth.currentUser?.uid)
        .where('hasNewMember', isEqualTo: true)
        .snapshots();
  }

  Future<void> _markNotificationAsRead(String roomId) async{
    await _firestore
        .collection('chatRooms')
        .doc(roomId)
        .update({'hasNewMember': false});
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Rooms",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _showUserInfo,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      RoomCreateScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child){
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),

      body: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _notificationsStream,
            builder: (context, snapshot){
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty){
                return const SizedBox.shrink();
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final room = snapshot.data!.docs[index];
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    color: Colors.blue.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.notification_important,
                          color: Colors.blue),
                      title: Text('${room['name']}に招待されました'),
                      subtitle: const Text('タップして確認'),
                      onTap: () async {
                        await _markNotificationAsRead(room.id);
                        if (!mounted) return;

                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    ChatScreen(roomId: room.id),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            transitionDuration:
                                const Duration(milliseconds: 300),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _auth.currentUser != null
                  ? _firestore
                      .collection('chatRooms')
                      .where('participants',
                          arrayContains: _auth.currentUser!.uid)
                      .snapshots()
                  : Stream.empty(),
              builder: (context, snapshot){
                if (snapshot.connectionState == ConnectionState.waiting){
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty){
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: (){
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        RoomCreateScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                                transitionDuration:
                                    const Duration(milliseconds: 300),
                              ),
                            );
                          },
                          child: const Text("新規ルーム作成"),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index){
                    var room = snapshot.data!.docs[index];
                    return Dismissible(
                      key: Key(room.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        padding: const EdgeInsets.only(right: 20),
                        alignment: Alignment.centerRight,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async{
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context){
                            return AlertDialog(
                              title: const Text("確認"),
                              content: const Text("本当に削除してもよろしいですか？"),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text("キャンセル"),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text("削除"),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) async{
                        try {
                          await _firestore
                              .collection('chatRooms')
                              .doc(room.id)
                              .delete();

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ChatRoomを削除ました')),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('削除に失敗ました: $e')),
                          );
                        }
                      },
                      child: ListTile(
                        title: Text(
                          room['name'] ?? 'Unnamed Room',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          room['lastMessage'] != null &&
                                  room['lastMessage'].toString().isNotEmpty
                              ? room['lastMessage']
                              : 'No messages',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        trailing: FutureBuilder<List<Widget>>(
                          future: _getParticipantIcons(room['participants']),
                          builder: (context, snapshot) {
                            if(snapshot.connectionState ==
                                ConnectionState.waiting){
                              return const CircularProgressIndicator();
                            }
                            if(snapshot.hasError){
                              return const Icon(Icons.error);
                            }
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: snapshot.data ?? [],
                            );
                          },
                        ),
                        onTap: (){
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      ChatScreen(roomId: room.id),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                const begin = 0.0;
                                const end = 1.0;
                                const curve = Curves.easeInOut;

                                var tween = Tween(begin: begin, end: end)
                                    .chain(CurveTween(curve: curve));
                                var fadeAnimation = animation.drive(tween);

                                return FadeTransition(
                                  opacity: fadeAnimation,
                                  child: child,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }



  Future<List<Widget>> _getParticipantIcons(
      List<dynamic> participantIds) async{
    List<Widget> icons = [];
    for (var id in participantIds){
      icons.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: CircleAvatar(
            child: Text(id[0].toUpperCase()),
            radius: 12,
          ),
        ),
      );
    }
    return icons;
  }
}