import 'package:flutter/material.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final List<Map<String, String>> meetings = [
    {'title': 'Team Sync', 'time': '10:00 AM, Today'},
    {'title': 'Client Review', 'time': '2:00 PM, Tomorrow'},
    {'title': 'Project Kickoff', 'time': '9:00 AM, Jun 5'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 30),
              const Text(
                'Meetings',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Schedule & manage your business meetings',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 25),
              Expanded(
                child: ListView.builder(
                  itemCount: meetings.length,
                  itemBuilder: (context, index) {
                    return _buildMeetingCard(
                      meetings[index]['title']!,
                      meetings[index]['time']!,
                      const Color(0xFF4CAF50),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add new meeting')),
          );
        },
        backgroundColor: const Color(0xFF4CAF50),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        const Text(
          'LBN',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildMeetingCard(String title, String time, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.video_call,
              color: Color(0xFF4CAF50),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Placeholder page classes (replace with your implementations)
class OneToOneScreen extends StatelessWidget {
  const OneToOneScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('One-to-One'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(child: Text('One-to-One Page')),
    );
  }
}

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(child: Text('Events Page')),
    );
  }
}

class VisitorsScreen extends StatelessWidget {
  const VisitorsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitors'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(child: Text('Visitors Page')),
    );
  }
}

class ReferencesScreen extends StatelessWidget {
  const ReferencesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('References'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(child: Text('References Page')),
    );
  }
}

class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(child: Text('Connections Page')),
    );
  }
}

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(child: Text('Gallery Page')),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 30),
              _buildTitleSection(),
              const SizedBox(height: 25),
              Expanded(
                child: _buildFeatureCards(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'LBN',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        Row(
          children: [
            Icon(Icons.search, color: Colors.black.withOpacity(0.8), size: 24),
            const SizedBox(width: 16),
            Icon(Icons.person_outline_sharp, color: Colors.black.withOpacity(0.8), size: 24),
          ],
        ),
      ],
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Business Network',
          style: TextStyle(
            color: Colors.black,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connect, collaborate, and grow your professional network',
          style: TextStyle(
            color: Colors.black.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCards() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 0.85,
      children: [
        _buildFeatureCard(
          'Meetings',
          'Schedule & manage your business meetings',
          Icons.video_call,
          const Color(0xFF4CAF50),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MeetingsScreen()),
          ),
        ),
        _buildFeatureCard(
          'One-to-One',
          'Personal networking sessions',
          Icons.person_add,
          const Color(0xFF2196F3),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const OneToOneScreen()),
          ),
        ),
        _buildFeatureCard(
          'Events',
          'Discover networking events near you',
          Icons.event,
          const Color(0xFFF44336),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EventsScreen()),
          ),
        ),
        _buildFeatureCard(
          'Visitors',
          'Track and manage your office visitors',
          Icons.people,
          const Color(0xFF9C27B0),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VisitorsScreen()),
          ),
        ),
        _buildFeatureCard(
          'References',
          'Professional recommendations',
          Icons.star,
          const Color(0xFFFFC107),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReferencesScreen()),
          ),
        ),
        _buildFeatureCard(
          'Connections',
          'Expand your professional network',
          Icons.connect_without_contact,
          const Color(0xFF009688),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ConnectionsScreen()),
          ),
        ),
        _buildFeatureCard(
          'Gallery',
          'Events Gallery',
          Icons.photo_size_select_actual_outlined,
          const Color(0xFF607D8B),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GalleryScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    String title,
    String description,
    IconData icon,
    Color iconColor,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(20),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(
          color: Colors.black.withOpacity(0.1),
        ),
        elevation: 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '0',
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.black.withOpacity(0.7),
              fontSize: 12,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: iconColor,
                  size: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}