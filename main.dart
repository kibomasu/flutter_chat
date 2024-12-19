import 'package:chat/chatroom_list_screen.dart';
import 'package:chat/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget{
  const MyApp({super.key});

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title: 'Flutter Chat UI Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthHandler(), // 自動ログインハンドラーを起動
    );
  }
}

class AuthHandler extends StatefulWidget{
  const AuthHandler({super.key});

  @override
  State<AuthHandler> createState() => _AuthHandlerState();
}

class _AuthHandlerState extends State<AuthHandler>{
  bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState(){
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async{
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('firebase_token');

    if (token != null && token.isNotEmpty){
      try{
        // トークンを検証する（サーバーやFirebaseの認証用）
        final user = FirebaseAuth.instance.currentUser;
        if (user != null){
          print("ユーザはトークンでログインしています： $token");
          setState((){
            _isLoggedIn = true;
          });
        }else{
          // 日本語で出力して
          print("Firebaseに現在のユーザーがいません。");
        }
      }catch (e){
        print("トークン検証中にエラーが発生しました： $e");
      }
    }
    setState((){
      _isLoading = false; // ローディング終了
    });
  }

  @override
  Widget build(BuildContext context){
    if (_isLoading){
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ログイン状態に応じて表示画面を切り替え
    return _isLoggedIn ? const ChatRoomListScreen() : LoginScreen();
  }
}