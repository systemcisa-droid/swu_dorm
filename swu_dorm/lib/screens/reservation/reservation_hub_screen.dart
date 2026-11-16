import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/reservation_strings.dart';
import '../../utils/share_room_strings.dart';
import '../../utils/ladder_strings.dart';
import 'reservation_screen.dart';
import 'share_room_screen.dart';
import 'ladder_game_screen.dart';

/// '예약' 메뉴를 누르면 가장 먼저 뜨는 화면. 세미나실 예약과 나눔방 중
/// 하나를 선택하면 각각의 화면으로 이동한다.
class ReservationHubScreen extends StatelessWidget {
  const ReservationHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LocaleProvider>(context).isEnglish;
    final s = ReservationStrings(isEnglish);
    final shareS = ShareRoomStrings(isEnglish);
    final ladderS = LadderStrings(isEnglish);
    return Scaffold(
      appBar: AppBar(title: Text(s.hubTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _HubCard(
              icon: Icons.meeting_room_outlined,
              iconColor: Colors.indigo,
              title: s.title,
              subtitle: s.hubSeminarRoomSubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReservationScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _HubCard(
              icon: Icons.diversity_3_outlined,
              iconColor: Colors.teal,
              title: shareS.title,
              subtitle: s.hubShareRoomSubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ShareRoomScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _HubCard(
              icon: Icons.alt_route,
              iconColor: Colors.deepOrange,
              title: ladderS.title,
              subtitle: ladderS.hubSubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LadderGameScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
