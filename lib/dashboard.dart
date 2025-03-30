import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import 'dart:async';
import 'auth_service.dart';
import 'blynk_service.dart'; // Import the Blynk service

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _blynkService = BlynkService(); // Initialize Blynk service
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoggingOut = false;
  
  // Selected train data
  String _selectedTrain = 'Train A-123';
  final List<String> _trainOptions = ['Train A-123', 'Train B-456', 'Train C-789', 'Train D-012'];
  
  // Weight data
  double _currentWeight = 42.5; // tons - will be updated with real data
  double _minWeightLimit = 20.0; // tons
  double _maxWeightLimit = 50.0; // tons
  bool _isOverweight = false;
  bool _isUnderweight = false;
  bool _isClearanceGiven = false;
  bool _sendAlertEnabled = false; // New property for alert switch
  
  // Data loading states
  bool _isLoadingWeight = true;
  bool _isLoadingHistory = true;
  
  // Timer for periodic updates
  Timer? _updateTimer;
  
  // Map controller
  GoogleMapController? _mapController;
  final LatLng _trainLocation = const LatLng(28.6139, 77.2090); // Delhi coordinates as example
  
  // Weight history data for graph
  List<FlSpot> _weightData = [
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
    
    // Fetch initial data
    _fetchInitialData();
    
    // Start periodic updates
    _startPeriodicUpdates();
  }
  
  // Fetch initial data from Blynk
  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoadingWeight = true;
      _isLoadingHistory = true;
    });
    
    try {
      // Get current weight
      final weight = await _blynkService.getCurrentWeight();
      if (mounted) {
        setState(() {
          _currentWeight = weight;
          _isLoadingWeight = false;
          _checkWeightStatus();
        });
      }
      
      // Get weight history
      final history = await _blynkService.getWeightHistory();
      if (history.isNotEmpty && mounted) {
        // Convert history to FlSpot list for the chart
        final spots = <FlSpot>[];
        for (int i = 0; i < history.length && i < 6; i++) {
          spots.add(FlSpot(i.toDouble(), history[i]));
        }
        
        setState(() {
          _weightData = spots;
          _isLoadingHistory = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      print('Error fetching initial data: $e');
      if (mounted) {
        setState(() {
          _isLoadingWeight = false;
          _isLoadingHistory = false;
        });
      }
    }
  }
  
  // Start periodic updates
  void _startPeriodicUpdates() {
    // Update every 1 second instead of 5
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        // Get current weight
        final weight = await _blynkService.getCurrentWeight();
        if (mounted) {
          setState(() {
            _currentWeight = weight;
            
            // Update weight history by shifting data points
            if (_weightData.isNotEmpty) {
              final newData = <FlSpot>[];
              for (int i = 1; i < _weightData.length; i++) {
                newData.add(FlSpot(i - 1.0, _weightData[i].y));
              }
              newData.add(FlSpot(_weightData.length - 1.0, weight));
              _weightData = newData;
            }
            
            _checkWeightStatus();
          });
        }
      } catch (e) {
        print('Error updating weight: $e');
      }
    });
  }
  
  void _checkWeightStatus() {
    setState(() {
      _isOverweight = _currentWeight > _maxWeightLimit;
      _isUnderweight = _currentWeight < _minWeightLimit;
      
      // Generate random alert for demo if weight changes significantly
      if (!_hasAlert && math.Random().nextDouble() < 0.2) {
        final weightChange = (_weightData.isNotEmpty && _weightData.length > 1) 
            ? _weightData.last.y - _weightData[_weightData.length - 2].y 
            : 0.0;
            
        if (weightChange.abs() > 2.0) {
          _hasAlert = true;
          _alertMessage = 'Weight change detected: ${weightChange.toStringAsFixed(1)} tons. Possible cargo shift alert!';
        }
      }
    });
  }
  
  // Improve the toggleClearance method with better error handling
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
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20, 
              height: 20, 
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Updating clearance status...'),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
    
    setState(() {
      _isClearanceGiven = !_isClearanceGiven;
    });
    
    // Send clearance status to Blynk
    _blynkService.setClearance(_isClearanceGiven).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  _isClearanceGiven ? Icons.check_circle : Icons.cancel, 
                  color: Colors.white
                ),
                const SizedBox(width: 12),
                Text(_isClearanceGiven 
                  ? 'Clearance given to train' 
                  : 'Clearance revoked from train'
                ),
              ],
            ),
            backgroundColor: _isClearanceGiven 
              ? Colors.green.shade600 
              : Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }).catchError((error) {
      print('Error updating clearance: $error');
      if (mounted) {
        setState(() {
          // Revert state if there was an error
          _isClearanceGiven = !_isClearanceGiven;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Text('Failed to update clearance status: ${error.toString()}'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }
  
  // Improve the toggleSendAlert method with better error handling
  void _toggleSendAlert() {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20, 
              height: 20, 
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Updating alert status...'),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
    
    setState(() {
      _sendAlertEnabled = !_sendAlertEnabled;
    });
    
    // Send alert status to Blynk
    _blynkService.sendAlert(_sendAlertEnabled).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info, color: Colors.white),
                const SizedBox(width: 12),
                Text(_sendAlertEnabled 
                  ? 'Alerts enabled and sent to monitoring system' 
                  : 'Alerts disabled'
              ),
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
    }
  }).catchError((error) {
    print('Error updating alert status: $error');
    if (mounted) {
      setState(() {
        // Revert state if there was an error
        _sendAlertEnabled = !_sendAlertEnabled;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Text('Failed to update alert status: ${error.toString()}'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
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
    _updateTimer?.cancel(); // Cancel the timer when disposing
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
      body: Column(
        children: [
          // App Bar - Now only the navbar is fixed at the top
          _buildAppBar(user),
          
          // Main Content - Separate from the navbar
          Expanded(
            child: Container(
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
                top: false, // Don't add safe area padding at the top since we have the navbar
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Train Selector and Alert Banner
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Padding(
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
                        ),
                      ),
                      
                      // Tab Bar
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildTabBar(),
                          ),
                        ),
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
            ),
          ),
        ],
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
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
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
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vector Shield',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        Text(
                          'Train Monitoring Dashboard',
                          style: TextStyle(
                            fontSize: 14,
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
                      radius: 18,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        user?.email?.isNotEmpty == true ? user!.email![0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isLoggingOut
                      ? SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue.shade700,
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            Icons.logout_rounded,
                            color: Colors.blue.shade700,
                            size: 28,
                          ),
                          onPressed: _signOut,
                          tooltip: 'Logout',
                        ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTrainSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
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
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Train',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedTrain,
                  isExpanded: true,
                  underline: Container(),
                  icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade700, size: 26),
                  style: TextStyle(
                    fontSize: 18,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  size: 16,
                  color: _isOverweight 
                    ? Colors.red.shade700 
                    : _isUnderweight 
                      ? Colors.amber.shade700 
                      : Colors.green.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  _isOverweight 
                    ? 'Overload' 
                    : _isUnderweight 
                      ? 'Underload' 
                      : 'Normal',
                  style: TextStyle(
                    fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALERT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                Text(
                  _alertMessage,
                  style: TextStyle(
                    fontSize: 15,
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
              size: 18,
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
          padding: const EdgeInsets.symmetric(vertical: 12),
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
                size: 24,
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
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
    int crossAxisCount = screenSize.width < 600 ? 2 : 4;
    
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Status Cards - Now with real-time weight and alert switch
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
                  _buildCompactAlertCard(), // New alert card
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
        ),
      ),
    );
  }
  
  Widget _buildAnalyticsTab(Size screenSize) {
    // Calculate responsive grid columns based on screen width
    int crossAxisCount = screenSize.width < 600 ? 2 : 4;
    
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Weight History Graph - Now with real-time data
              _buildWeightHistoryCard(),
              
              const SizedBox(height: 16),
              
              // Analytics Cards - Now 4 cards in one row on wide screens, 2 on mobile
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                children: [
                  _buildAnalyticsCard(
                    'Avg. Weight',
                    '${(_weightData.map((spot) => spot.y).reduce((a, b) => a + b) / _weightData.length).toStringAsFixed(1)} tons',
                    Icons.scale,
                    Colors.purple,
                    '+${(_currentWeight - (_weightData.isNotEmpty ? _weightData.first.y : _currentWeight)).toStringAsFixed(1)} from start',
                  ),
                  _buildAnalyticsCard(
                    'Alerts',
                    '${_hasAlert ? "1" : "0"}',
                    Icons.warning_amber,
                    Colors.orange,
                    _hasAlert ? '1 active' : 'No active alerts',
                  ),
                  _buildAnalyticsCard(
                    'Efficiency',
                    '${((_currentWeight / _maxWeightLimit) * 100).toStringAsFixed(0)}%',
                    Icons.speed,
                    Colors.green,
                    'Load efficiency',
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
        ),
      ),
    );
  }
  
  Widget _buildLocationTab(Size screenSize) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            // GPS Location Map
            Expanded(
              child: _buildLocationCard(),
            ),
            
            const SizedBox(height: 16),
            
            // Location Details
            Container(
              padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Current: Delhi Central Station',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.flag,
                        size: 20,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Destination: Mumbai Central',
                          style: TextStyle(
                            fontSize: 14,
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
        ),
      ),
    );
  }
  
  Widget _buildLocationDetail(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          size: 22,
          color: Colors.blue.shade700,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
  
  Widget _buildCompactWeightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Current Weight',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: _isLoadingWeight
                ? CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue.shade700,
                  )
                : Column(
                    children: [
                      Text(
                        '${_currentWeight.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 32,
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
                          fontSize: 16,
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
            minHeight: 6,
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompactClearanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Clearance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _isClearanceGiven ? Colors.green.shade100 : Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _isClearanceGiven ? Icons.check_circle : Icons.cancel,
                  size: 36,
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
                padding: const EdgeInsets.symmetric(vertical: 10),
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
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // New card for alert switch
  Widget _buildCompactAlertCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                Icons.notifications_active,
                color: Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Alert Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _sendAlertEnabled ? Colors.amber.shade100 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _sendAlertEnabled ? Icons.notifications_active : Icons.notifications_off,
                  size: 36,
                  color: _sendAlertEnabled ? Colors.amber.shade700 : Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _toggleSendAlert,
              style: ElevatedButton.styleFrom(
                backgroundColor: _sendAlertEnabled 
                  ? Colors.grey.shade100 
                  : Colors.amber.shade100,
                foregroundColor: _sendAlertEnabled 
                  ? Colors.grey.shade700 
                  : Colors.amber.shade700,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                _sendAlertEnabled ? 'Disable' : 'Enable',
                style: const TextStyle(
                  fontSize: 15,
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
      padding: const EdgeInsets.all(16),
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
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
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
              _fetchInitialData();
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
          const SizedBox(height: 10),
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
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 15)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.shade50,
          foregroundColor: color.shade700,
          padding: const EdgeInsets.symmetric(vertical: 10),
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
      padding: const EdgeInsets.all(16),
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
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Weight Limits',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Min:',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              Text(
                '${_minWeightLimit.toStringAsFixed(1)} tons',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Max:',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              Text(
                '${_maxWeightLimit.toStringAsFixed(1)} tons',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
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
              _fetchInitialData();
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
        const SizedBox(width: 10),
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
        const SizedBox(width: 10),
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: color.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
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
      padding: const EdgeInsets.all(16),
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
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Weight History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                icon: Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.blue.shade700,
                ),
                label: Text(
                  'Last 24 hours',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 14,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                ),
                onPressed: () {
                  // Show time range selector
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _isLoadingHistory
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue.shade700,
                    ),
                  )
                : LineChart(
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
                            reservedSize: 28,
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
                                  fontSize: 11,
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
                                  fontSize: 11,
                                ),
                              );
                            },
                            reservedSize: 36,
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
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
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
                          barWidth: 1.5,
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
                          barWidth: 1.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          dashArray: [5, 5],
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.blue.shade500,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Weight',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 10,
                height: 2.5,
                decoration: BoxDecoration(
                  color: Colors.red.shade300,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Max',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 10,
                height: 2.5,
                decoration: BoxDecoration(
                  color: Colors.amber.shade300,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Min',
                style: TextStyle(
                  fontSize: 12,
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
      padding: const EdgeInsets.all(16),
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
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
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
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: color.shade700,
              ),
            ),
          ),
          const Spacer(),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
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

