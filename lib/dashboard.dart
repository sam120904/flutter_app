import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import 'auth_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoggingOut = false;
  
  // Selected train data
  String _selectedTrain = 'Train A-123';
  final List<String> _trainOptions = ['Train A-123', 'Train B-456', 'Train C-789', 'Train D-012'];
  
  // Weight data
  double _currentWeight = 42.5; // tons
  double _minWeightLimit = 20.0; // tons
  double _maxWeightLimit = 50.0; // tons
  bool _isOverweight = false;
  bool _isUnderweight = false;
  bool _isClearanceGiven = false;
  
  // Map controller
  GoogleMapController? _mapController;
  final LatLng _trainLocation = const LatLng(28.6139, 77.2090); // Delhi coordinates as example
  
  // Weight history data for graph
  final List<FlSpot> _weightData = [
    const FlSpot(0, 30),
    const FlSpot(1, 35),
    const FlSpot(2, 38),
    const FlSpot(3, 40),
    const FlSpot(4, 42),
    const FlSpot(5, 42.5),
  ];
  
  // Alert data
  bool _hasAlert = false;
  String _alertMessage = '';
  
  // Tab selection
  int _selectedTabIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
    
    // Check weight status
    _checkWeightStatus();
  }
  
  void _checkWeightStatus() {
    setState(() {
      _isOverweight = _currentWeight > _maxWeightLimit;
      _isUnderweight = _currentWeight < _minWeightLimit;
      
      // Generate random alert for demo
      if (math.Random().nextBool() && !_hasAlert) {
        _hasAlert = true;
        _alertMessage = 'Weight change detected: -2.3 tons. Possible cargo theft alert!';
      }
    });
  }
  
  void _toggleClearance() {
  // Don't allow clearance to be given if weight is out of range
  if (_isOverweight || _isUnderweight) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            const Text('Cannot give clearance when weight is out of range'),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    return;
  }
  
  setState(() {
    _isClearanceGiven = !_isClearanceGiven;
    if (_isClearanceGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Clearance given to train'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cancel, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Clearance revoked from train'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  });
}
  
  void _dismissAlert() {
    setState(() {
      _hasAlert = false;
      _alertMessage = '';
    });
  }
  
  void _updateWeightLimits(double min, double max) {
    setState(() {
      _minWeightLimit = min;
      _maxWeightLimit = max;
      _checkWeightStatus();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    setState(() {
      _isLoggingOut = true;
    });
    
    try {
      await _authService.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Logged out successfully'),
              ],
            ),
            backgroundColor: Colors.blue.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Navigate to login page after logout
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.pushReplacementNamed(context, '/login');
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Error logging out'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.teal.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              _buildAppBar(user),
              
              // Main Content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Train Selector and Alert Banner
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          children: [
                            _buildTrainSelector(),
                            if (_hasAlert) 
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _buildAlertBanner(),
                              ),
                          ],
                        ),
                      ),
                      
                      // Tab Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildTabBar(),
                      ),
                      
                      // Tab Content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildTabContent(screenSize),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAppBar(User? user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vector Shield',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  Text(
                    'Train Monitoring Dashboard',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  user?.email?.isNotEmpty == true ? user!.email![0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isLoggingOut
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue.shade700,
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      Icons.logout_rounded,
                      color: Colors.blue.shade700,
                    ),
                    onPressed: _signOut,
                    tooltip: 'Logout',
                  ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrainSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.train,
            color: Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Train',
                  style: TextStyle(
                    fontSize: 14, // Increased from 12
                    color: Colors.grey.shade600,
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedTrain,
                  isExpanded: true,
                  underline: Container(),
                  icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade700, size: 22), // Increased from 20
                  style: TextStyle(
                    fontSize: 16, // Increased from 14
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedTrain = newValue;
                      });
                    }
                  },
                  items: _trainOptions.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _isOverweight 
                ? Colors.red.shade100 
                : _isUnderweight 
                  ? Colors.amber.shade100 
                  : Colors.green.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isOverweight 
                    ? Icons.error 
                    : _isUnderweight 
                      ? Icons.warning 
                      : Icons.check_circle,
                  size: 14,
                  color: _isOverweight 
                    ? Colors.red.shade700 
                    : _isUnderweight 
                      ? Colors.amber.shade700 
                      : Colors.green.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  _isOverweight 
                    ? 'Overload' 
                    : _isUnderweight 
                      ? 'Underload' 
                      : 'Normal',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isOverweight 
                      ? Colors.red.shade700 
                      : _isUnderweight 
                        ? Colors.amber.shade700 
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.red.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALERT',
                  style: TextStyle(
                    fontSize: 14, // Increased from 12
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                Text(
                  _alertMessage,
                  style: TextStyle(
                    fontSize: 13, // Increased from 11
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.red.shade700,
              size: 16,
            ),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            onPressed: _dismissAlert,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabButton(0, 'Overview', Icons.dashboard_outlined),
          _buildTabButton(1, 'Analytics', Icons.analytics_outlined),
          _buildTabButton(2, 'Location', Icons.location_on_outlined),
        ],
      ),
    );
  }
  
  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14, // Increased from 12
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTabContent(Size screenSize) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab(screenSize);
      case 1:
        return _buildAnalyticsTab(screenSize);
      case 2:
        return _buildLocationTab(screenSize);
      default:
        return _buildOverviewTab(screenSize);
    }
  }
  
  Widget _buildOverviewTab(Size screenSize) {
    // Calculate responsive grid columns based on screen width
    int crossAxisCount = screenSize.width < 600 ? 2 : 3;
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // Status Cards
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            children: [
              _buildCompactWeightCard(),
              _buildCompactClearanceCard(),
              _buildCompactActionsCard(),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Weight Limits Card
          _buildCompactWeightLimitsCard(),
          
          const SizedBox(height: 16),
          
          // Quick Actions
          _buildQuickActionsRow(),
        ],
      ),
    );
  }
  
  Widget _buildAnalyticsTab(Size screenSize) {
  return SingleChildScrollView(
    child: Column(
      children: [
        // Weight History Graph
        _buildWeightHistoryCard(),
        
        const SizedBox(height: 16),
        
        // Additional Analytics Cards - Make them more compact
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5, // Increased from 1.2 to make cards shorter
          ),
          children: [
            _buildAnalyticsCard(
              'Avg. Weight',
              '38.2 tons',
              Icons.scale,
              Colors.purple,
              '+2.3 from last week',
            ),
            _buildAnalyticsCard(
              'Alerts',
              '3',
              Icons.warning_amber,
              Colors.orange,
              '2 resolved, 1 pending',
            ),
            _buildAnalyticsCard(
              'Efficiency',
              '92%',
              Icons.speed,
              Colors.green,
              '+5% from last month',
            ),
            _buildAnalyticsCard(
              'Distance',
              '1,245 km',
              Icons.route,
              Colors.blue,
              'This month',
            ),
          ],
        ),
      ],
    ),
  );
}
  
  Widget _buildLocationTab(Size screenSize) {
    return Column(
      children: [
        // GPS Location Map
        Expanded(
          child: _buildLocationCard(),
        ),
        
        const SizedBox(height: 16),
        
        // Location Details
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLocationDetail(Icons.speed, 'Speed', '45 km/h'),
                  _buildLocationDetail(Icons.navigation, 'Direction', 'North'),
                  _buildLocationDetail(Icons.timer, 'ETA', '2h 15m'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Current: Delhi Central Station',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.flag,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Destination: Mumbai Central',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildLocationDetail(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.blue.shade700,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12, // Increased from 10
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14, // Increased from 12
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
  
  Widget _buildCompactWeightCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.scale,
                color: Colors.blue.shade700,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Current Weight',
                style: TextStyle(
                  fontSize: 14, // Increased from 12
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Column(
              children: [
                Text(
                  '${_currentWeight.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 28, // Increased from 24
                    fontWeight: FontWeight.bold,
                    color: _isOverweight 
                      ? Colors.red.shade700 
                      : _isUnderweight 
                        ? Colors.amber.shade700 
                        : Colors.blue.shade700,
                  ),
                ),
                Text(
                  'tons',
                  style: TextStyle(
                    fontSize: 14, // Increased from 12
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          LinearProgressIndicator(
            value: _currentWeight / (_maxWeightLimit * 1.2), // Scale for visual effect
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              _isOverweight 
                ? Colors.red.shade500 
                : _isUnderweight 
                  ? Colors.amber.shade500 
                  : Colors.green.shade500,
            ),
            borderRadius: BorderRadius.circular(10),
            minHeight: 4,
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactClearanceCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified,
                color: Colors.blue.shade700,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Clearance',
                style: TextStyle(
                  fontSize: 14, // Increased from 12
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _isClearanceGiven ? Colors.green.shade100 : Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _isClearanceGiven ? Icons.check_circle : Icons.cancel,
                  size: 30,
                  color: _isClearanceGiven ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isOverweight || _isUnderweight) ? null : _toggleClearance,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isClearanceGiven 
                  ? Colors.red.shade100 
                  : (_isOverweight || _isUnderweight) 
                    ? Colors.grey.shade200 
                    : Colors.green.shade100,
                foregroundColor: _isClearanceGiven 
                  ? Colors.red.shade700 
                  : (_isOverweight || _isUnderweight) 
                    ? Colors.grey.shade500 
                    : Colors.green.shade700,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                (_isOverweight || _isUnderweight)
                  ? 'Not Available'
                  : (_isClearanceGiven ? 'Revoke' : 'Give'),
                style: TextStyle(
                  fontSize: 13, // Increased from 12
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactActionsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flash_on,
                color: Colors.blue.shade700,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 14, // Increased from 12
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildMiniActionButton(
            icon: Icons.refresh,
            label: 'Refresh',
            color: Colors.blue,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Data refreshed'),
                  backgroundColor: Colors.blue.shade600,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _buildMiniActionButton(
            icon: Icons.report_problem,
            label: 'Report',
            color: Colors.orange,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'Report an Issue',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: const Text('This feature is not available in the demo version.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildMiniActionButton({
    required IconData icon,
    required String label,
    required MaterialColor color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 16), // Increased from 14
        label: Text(label, style: const TextStyle(fontSize: 13)), // Increased from 11
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.shade50,
          foregroundColor: color.shade700,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: color.shade200),
          ),
          elevation: 0,
        ),
      ),
    );
  }
  
  Widget _buildCompactWeightLimitsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune,
                color: Colors.blue.shade700,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Weight Limits',
                style: TextStyle(
                  fontSize: 14, // Increased from 12
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Min:',
                    style: TextStyle(
                      fontSize: 13, // Increased from 11
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              Text(
                '${_minWeightLimit.toStringAsFixed(1)} tons',
                style: TextStyle(
                  fontSize: 13, // Increased from 11
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: _minWeightLimit,
              min: 0,
              max: _maxWeightLimit - 5, // Ensure min is always less than max
              divisions: 50,
              activeColor: Colors.amber.shade400,
              inactiveColor: Colors.grey.shade200,
              onChanged: (value) {
                setState(() {
                  _minWeightLimit = value;
                  _checkWeightStatus();
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Max:',
                    style: TextStyle(
                      fontSize: 13, // Increased from 11
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              Text(
                '${_maxWeightLimit.toStringAsFixed(1)} tons',
                style: TextStyle(
                  fontSize: 13, // Increased from 11
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: _maxWeightLimit,
              min: _minWeightLimit + 5, // Ensure max is always greater than min
              max: 100,
              divisions: 50,
              activeColor: Colors.red.shade400,
              inactiveColor: Colors.grey.shade200,
              onChanged: (value) {
                setState(() {
                  _maxWeightLimit = value;
                  _checkWeightStatus();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActionsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionChip(
            icon: Icons.refresh,
            label: 'Refresh',
            color: Colors.blue,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Data refreshed'),
                  backgroundColor: Colors.blue.shade600,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionChip(
            icon: Icons.report_problem,
            label: 'Report',
            color: Colors.orange,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'Report an Issue',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: const Text('This feature is not available in the demo version.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionChip(
            icon: Icons.history,
            label: 'History',
            color: Colors.purple,
            onPressed: () {
              setState(() {
                _selectedTabIndex = 1; // Switch to Analytics tab
              });
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required MaterialColor color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: color.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14, // Increased from 12
                    fontWeight: FontWeight.bold,
                    color: color.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildWeightHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.show_chart,
                    color: Colors.blue.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Weight History',
                    style: TextStyle(
                      fontSize: 14, // Increased from 12
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                icon: Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.blue.shade700,
                ),
                label: Text(
                  'Last 24 hours',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12, // Increased from 10
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                onPressed: () {
                  // Show time range selector
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 10,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        String text = '';
                        switch (value.toInt()) {
                          case 0:
                            text = '6h ago';
                            break;
                          case 1:
                            text = '5h ago';
                            break;
                          case 2:
                            text = '4h ago';
                            break;
                          case 3:
                            text = '3h ago';
                            break;
                          case 4:
                            text = '2h ago';
                            break;
                          case 5:
                            text = '1h ago';
                            break;
                        }
                        
                        return Text(
                          text,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 10,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 9,
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade200),
                ),
                minX: 0,
                maxX: 5,
                minY: 0,
                maxY: 60,
                lineBarsData: [
                  LineChartBarData(
                    spots: _weightData,
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade400,
                        Colors.blue.shade700,
                      ],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: Colors.blue.shade700,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade200.withOpacity(0.3),
                          Colors.blue.shade700.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Add threshold lines
                  LineChartBarData(
                    spots: [
                      FlSpot(0, _maxWeightLimit),
                      FlSpot(5, _maxWeightLimit),
                    ],
                    isCurved: false,
                    color: Colors.red.shade300,
                    barWidth: 1,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
                  LineChartBarData(
                    spots: [
                      FlSpot(0, _minWeightLimit),
                      FlSpot(5, _minWeightLimit),
                    ],
                    isCurved: false,
                    color: Colors.amber.shade300,
                    barWidth: 1,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.blue.shade500,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Weight',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.red.shade300,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Max',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.amber.shade300,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Min',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnalyticsCard(
    String title,
    String value,
    IconData icon,
    MaterialColor color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color.shade700,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14, // Increased from 12
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 26, // Increased from 24
                fontWeight: FontWeight.bold,
                color: color.shade700,
              ),
            ),
          ),
          const Spacer(),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12, // Increased from 10
                  color: color.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _trainLocation,
            zoom: 14,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
          },
          markers: {
            Marker(
              markerId: const MarkerId('train'),
              position: _trainLocation,
              infoWindow: InfoWindow(
                title: _selectedTrain,
                snippet: 'Speed: 45 km/h, Direction: North',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            ),
          },
          myLocationEnabled: true,
          compassEnabled: true,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }
}

