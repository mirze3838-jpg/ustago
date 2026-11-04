import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'artisan_detail_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String _selectedFilter = 'all'; // 'all', 'pending', 'verified'

  Future<void> _verifyArtisan(String uid, bool verify) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isVerified': verify,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(verify ? 'Usta təsdiqləndi!' : 'Təsdiq ləğv edildi.'),
            backgroundColor: verify ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xəta: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UstaGo Admin Paneli'),
        backgroundColor: const Color(0xFF1769D2),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final artisans = docs.where((d) => d.data()['role'] == 'usta' || d.data()['role'] == 'worker').toList();
          final customers = docs.where((d) => d.data()['role'] == 'customer').toList();

          List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs = artisans;
          if (_selectedFilter == 'pending') {
            filteredDocs = artisans.where((d) => d.data()['isVerified'] != true).toList();
          } else if (_selectedFilter == 'verified') {
            filteredDocs = artisans.where((d) => d.data()['isVerified'] == true).toList();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Statistika Kartları
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Ümumi İstifadəçi', '${docs.length}', Icons.people, Colors.blue),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard('Ustalar', '${artisans.length}', Icons.handyman, Colors.orange),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard('Müştərilər', '${customers.length}', Icons.person, Colors.green),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Filter düymələri
              Row(
                children: [
                  _buildFilterChip('Hamısı', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Təsdiq Gözləyənlər', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Təsdiqlənmişlər', 'verified'),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                'Ustaların Siyahısı (${filteredDocs.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              if (filteredDocs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Bu kateqoriyada usta tapılmadı.', style: TextStyle(color: Colors.grey)),
                  ),
                ),

              ...filteredDocs.map((doc) {
                final data = doc.data();
                final name = data['fullName'] ?? 'Adsız';
                final email = data['email'] ?? '';
                final phone = data['phone'] ?? '';
                final bool isVerified = data['isVerified'] == true;
                final bool hasVideo = (data['videoUrl'] as String?)?.isNotEmpty == true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: const Icon(Icons.handyman, color: Color(0xFF1769D2)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(width: 6),
                                      if (isVerified)
                                        const Icon(Icons.verified, color: Colors.blue, size: 18),
                                    ],
                                  ),
                                  Text('$email • $phone', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Əgər video varsa "Videoya bax"
                            if (hasVideo)
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ArtisanDetailScreen(artisanData: data)),
                                  );
                                },
                                icon: const Icon(Icons.play_circle_outline, size: 18),
                                label: const Text('Videosuna bax'),
                              )
                            else
                              const Text('Video yükləməyib', style: TextStyle(color: Colors.red, fontSize: 12)),

                            const Spacer(),

                            // Təsdiqlə / Təsdiqi ləğv et
                            if (!isVerified)
                              FilledButton.icon(
                                onPressed: () => _verifyArtisan(doc.id, true),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Təsdiqlə'),
                                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: () => _verifyArtisan(doc.id, false),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Ləğv et'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black87), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final bool isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = filterKey);
      },
    );
  }
}
