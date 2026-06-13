import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/home/home_screen.dart';
import 'features/upload/upload_screen.dart';
import 'features/analysis/analysis_screen.dart';
import 'features/opportunity/opportunity_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/roadmap/roadmap_screen.dart';
import 'features/profile/profile_screen.dart';

void main() {
  runApp(const OpportunityFlowApp());
}

class OpportunityFlowApp extends StatelessWidget {
  const OpportunityFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpportunityFlow AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/upload': (context) => const UploadScreen(),
        '/analysis': (context) => const AnalysisScreen(),
        '/opportunity': (context) => const OpportunityScreen(),
        '/chat': (context) => const ChatScreen(),
        '/roadmap': (context) => const RoadmapScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
