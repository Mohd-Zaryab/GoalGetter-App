import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goalgetter/utils/app_colors.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:math';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class GoalTrackerPage extends StatefulWidget {
  const GoalTrackerPage({super.key});

  @override
  _GoalTrackerPageState createState() => _GoalTrackerPageState();
}

class _GoalTrackerPageState extends State<GoalTrackerPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _addAmountController = TextEditingController();
  final TextEditingController _futureGoalAmountController =
      TextEditingController();

  late TabController _tabController;

  double _currentGoalAmount = 0.0;
  double _currentSavedAmount = 0.0;

  double _futureGoalTargetAmount = 0.0;
  int _futureGoalTotalDays = 0;
  List<bool> _futureGoalCompletionStatus = [];
  List<double> _futureGoalDailyAmounts = [];

  // New variables for currency selection
  String _selectedCurrencyCode = 'INR';
  String _currencySymbol = '₹';
  final Map<String, String> _currencyOptions = {
    'INR': '₹',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
  };

  bool _isDarkMode = false;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeNotifications();
    _loadData();
    // _getCurrencySymbol() will now be called in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCurrencySymbol(); // ✅ Correct place to call this function
  }

  @override
  void dispose() {
    _tabController.dispose();
    _goalController.dispose();
    _addAmountController.dispose();
    _futureGoalAmountController.dispose();
    super.dispose();
  }

  // --- Notification Logic ---
  _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('launcher_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  _scheduleDailyNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'daily_challenge_channel',
          'Daily Challenge Reminders',
          channelDescription: 'Reminders for your daily savings challenge.',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.periodicallyShow(
      0,
      'Daily Challenge',
      "Don't forget to save today! Your goals are waiting for you. ✨",
      RepeatInterval.daily,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  _cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // --- Data & State Management ---
  _updateCurrencySymbol() {
    final format = NumberFormat.simpleCurrency(
      locale: 'en_US',
      name: _selectedCurrencyCode,
    );
    _currencySymbol = format.currencySymbol;
    if (mounted) {
      setState(() {});
    }
  }

  _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentGoalAmount = prefs.getDouble('currentGoalAmount') ?? 0.0;
      _currentSavedAmount = prefs.getDouble('currentSavedAmount') ?? 0.0;
      _futureGoalTargetAmount =
          prefs.getDouble('futureGoalTargetAmount') ?? 0.0;
      _futureGoalTotalDays = prefs.getInt('futureGoalTotalDays') ?? 0;
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
      _selectedCurrencyCode = prefs.getString('selectedCurrencyCode') ?? 'INR';

      String? completionStatusJson = prefs.getString(
        'futureGoalCompletionStatus',
      );
      if (completionStatusJson != null && completionStatusJson.isNotEmpty) {
        _futureGoalCompletionStatus = List<bool>.from(
          jsonDecode(completionStatusJson),
        );
      } else {
        _futureGoalCompletionStatus = List<bool>.filled(
          _futureGoalTotalDays,
          false,
        );
      }

      String? dailyAmountsJson = prefs.getString('futureGoalDailyAmounts');
      if (dailyAmountsJson != null && dailyAmountsJson.isNotEmpty) {
        _futureGoalDailyAmounts = List<double>.from(
          jsonDecode(dailyAmountsJson),
        );
      } else {
        _futureGoalDailyAmounts = [];
      }

      if (_futureGoalCompletionStatus.length != _futureGoalTotalDays ||
          _futureGoalDailyAmounts.length != _futureGoalTotalDays) {
        _futureGoalCompletionStatus = List<bool>.filled(
          _futureGoalTotalDays,
          false,
        );
        _futureGoalDailyAmounts = [];
      }
    });
  }

  _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('currentGoalAmount', _currentGoalAmount);
    prefs.setDouble('currentSavedAmount', _currentSavedAmount);
    prefs.setDouble('futureGoalTargetAmount', _futureGoalTargetAmount);
    prefs.setInt('futureGoalTotalDays', _futureGoalTotalDays);
    prefs.setBool('isDarkMode', _isDarkMode);
    prefs.setBool('notificationsEnabled', _notificationsEnabled);
    prefs.setString('selectedCurrencyCode', _selectedCurrencyCode);
    prefs.setString(
      'futureGoalCompletionStatus',
      jsonEncode(_futureGoalCompletionStatus),
    );
    prefs.setString(
      'futureGoalDailyAmounts',
      jsonEncode(_futureGoalDailyAmounts),
    );
  }

  // --- Goal & Savings Logic ---
  _setCurrentGoal() {
    final goalText = _goalController.text;
    if (goalText.isNotEmpty) {
      double newGoal = double.tryParse(goalText) ?? 0.0;
      if (newGoal > 0) {
        setState(() {
          _currentGoalAmount = newGoal;
          _currentSavedAmount = 0.0;
        });
        _saveData();
        _goalController.clear();
        FocusScope.of(context).unfocus(); // Keyboard dismiss
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Current Goal Updated!')));
      }
    }
  }

  _addCurrentSavings() {
    final addText = _addAmountController.text;
    if (addText.isNotEmpty) {
      double amountToAdd = double.tryParse(addText) ?? 0.0;
      if (amountToAdd > 0) {
        setState(() {
          _currentSavedAmount += amountToAdd;
        });
        _saveData();
        _addAmountController.clear();
        FocusScope.of(context).unfocus(); // Keyboard dismiss
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added $_currencySymbol${amountToAdd.toStringAsFixed(2)} to current savings!',
            ),
          ),
        );
      }
    }
  }

  _useCurrentSavings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController useController = TextEditingController();
        return AlertDialog(
          backgroundColor: _isDarkMode
              ? AppColors.darkCardColor
              : AppColors.cardColor,
          title: const Text(
            'Used Savings',
            style: TextStyle(color: AppColors.textColor),
          ),
          content: TextField(
            controller: useController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textColor),
            decoration: InputDecoration(
              labelText: 'Amount you used',
              labelStyle: TextStyle(
                color: AppColors.textColor.withOpacity(0.7),
              ),
              prefixText: _currencySymbol,
              prefixStyle: const TextStyle(color: AppColors.textColor),
              filled: true,
              fillColor: _isDarkMode
                  ? AppColors.darkPrimaryColor
                  : AppColors.primaryColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.accentColor),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Confirm',
                style: TextStyle(color: AppColors.successColor),
              ),
              onPressed: () {
                double amountUsed = double.tryParse(useController.text) ?? 0.0;
                if (amountUsed > 0 && _currentSavedAmount >= amountUsed) {
                  setState(() {
                    _currentSavedAmount -= amountUsed;
                  });
                  _saveData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Used $_currencySymbol${amountUsed.toStringAsFixed(2)}. Current savings updated.',
                      ),
                    ),
                  );
                } else if (amountUsed > _currentSavedAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You cannot use more than you have saved.'),
                    ),
                  );
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  double get _currentProgressPercentage {
    if (_currentGoalAmount == 0.0) return 0.0;
    return (_currentSavedAmount / _currentGoalAmount).clamp(0.0, 1.0);
  }

  // --- Daily Challenge Logic ---
  _generateRandomDailyAmounts(double totalAmount, int days) {
    List<double> amounts = [];
    double remainingAmount = totalAmount;
    Random random = Random();

    for (int i = 0; i < days - 1; i++) {
      double maxAmountForDay = remainingAmount / (days - i) * 2;
      double amount = random.nextDouble() * maxAmountForDay;
      if (amount < 1.0) amount = 1.0;
      amounts.add(amount);
      remainingAmount -= amount;
    }
    amounts.add(remainingAmount);
    _futureGoalDailyAmounts = amounts;
  }

  _setFutureGoal() {
    final targetAmountText = _futureGoalAmountController.text;
    if (targetAmountText.isNotEmpty) {
      double newTargetAmount = double.tryParse(targetAmountText) ?? 0.0;
      if (newTargetAmount > 0) {
        _generateRandomDailyAmounts(newTargetAmount, 100);
        setState(() {
          _futureGoalTargetAmount = newTargetAmount;
          _futureGoalTotalDays = 100;
          _futureGoalCompletionStatus = List<bool>.filled(100, false);
        });
        _saveData();
        _futureGoalAmountController.clear();
        FocusScope.of(context).unfocus(); // Keyboard dismiss
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Daily Challenge Set!')));
      }
    }
  }

  _toggleFutureGoalDayCompletion(int index) async {
    double dailyAmount = _futureGoalDailyAmounts[index];
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode
              ? AppColors.darkCardColor
              : AppColors.cardColor,
          title: const Text(
            'Confirm Saving?',
            style: TextStyle(color: AppColors.textColor),
          ),
          content: Text(
            _futureGoalCompletionStatus[index]
                ? 'Are you sure you want to unmark Day ${index + 1}?'
                : 'Have you really saved $_currencySymbol${dailyAmount.toStringAsFixed(2)} for Day ${index + 1}?',
            style: const TextStyle(color: AppColors.textColor),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'No',
                style: TextStyle(color: AppColors.accentColor),
              ),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text(
                'Yes',
                style: TextStyle(color: AppColors.successColor),
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _futureGoalCompletionStatus[index] =
            !_futureGoalCompletionStatus[index];
      });
      _saveData();
    }
  }

  double get _currentFutureSavings {
    if (_futureGoalDailyAmounts.isEmpty) return 0.0;
    double savedAmount = 0.0;
    for (int i = 0; i < _futureGoalDailyAmounts.length; i++) {
      if (_futureGoalCompletionStatus[i]) {
        savedAmount += _futureGoalDailyAmounts[i];
      }
    }
    return savedAmount;
  }

  // --- Dialogs & UI ---
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _isDarkMode
              ? AppColors.darkCardColor
              : AppColors.cardColor,
          title: const Text(
            'About GoalGetter',
            style: TextStyle(
              color: AppColors.textColor,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'GoalGetter is a simple and effective tool designed to help you track your financial goals. Whether it\'s a short-term savings plan or a long-term daily challenge, this app provides the motivation and tools you need to succeed.',
                  style: TextStyle(
                    color: AppColors.textColor.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Developed by:',
                  style: TextStyle(
                    color: AppColors.textColor.withOpacity(0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Mohammad Zaryab',
                  style: TextStyle(color: AppColors.accentColor, fontSize: 18),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.successColor),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cardPadding = screenWidth > 600 ? 40.0 : 20.0;
    bool currentGoalAchieved =
        _currentSavedAmount >= _currentGoalAmount && _currentGoalAmount > 0;

    ThemeData currentTheme = _isDarkMode
        ? ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.darkPrimaryColor,
            cardColor: AppColors.darkCardColor,
            appBarTheme: const AppBarTheme(
              color: AppColors.darkPrimaryColor,
              elevation: 0,
            ),
          )
        : ThemeData.light().copyWith(
            scaffoldBackgroundColor: AppColors.primaryColor,
            cardColor: AppColors.cardColor,
            appBarTheme: const AppBarTheme(
              color: AppColors.primaryColor,
              elevation: 0,
            ),
          );

    return Theme(
      data: currentTheme,
      child: Scaffold(
        backgroundColor: currentTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'GoalGetter',
            style: TextStyle(
              color: AppColors.textColor,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Builder(
            builder: (BuildContext context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: AppColors.textColor),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: AppColors.textColor),
              onPressed: _showAboutDialog,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.textColor,
            indicatorColor: AppColors.accentColor,
            tabs: const [
              Tab(text: 'Current Goal'),
              Tab(text: 'Daily Challenge'),
              Tab(text: 'Settings'),
            ],
          ),
        ),
        drawer: Drawer(
          backgroundColor: currentTheme.cardColor,
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              const DrawerHeader(
                decoration: BoxDecoration(color: AppColors.primaryColor),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'GoalGetter',
                      style: TextStyle(
                        color: AppColors.accentColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Your path to financial success',
                      style: TextStyle(
                        color: AppColors.textColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.star, color: AppColors.textColor),
                title: const Text(
                  'Current Goal',
                  style: TextStyle(color: AppColors.textColor),
                ),
                onTap: () {
                  _tabController.animateTo(0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag, color: AppColors.textColor),
                title: const Text(
                  'Daily Challenge',
                  style: TextStyle(color: AppColors.textColor),
                ),
                onTap: () {
                  _tabController.animateTo(1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: AppColors.textColor),
                title: const Text(
                  'Settings',
                  style: TextStyle(color: AppColors.textColor),
                ),
                onTap: () {
                  _tabController.animateTo(2);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.info_outline,
                  color: AppColors.textColor,
                ),
                title: const Text(
                  'About',
                  style: TextStyle(color: AppColors.textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAboutDialog();
                },
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Current Goal
            SingleChildScrollView(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: currentTheme.cardColor,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: cardPadding,
                        vertical: 25,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Your Current Goal:',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.textColor.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$_currencySymbol${_currentGoalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Saved: $_currencySymbol${_currentSavedAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 15),
                          LinearProgressIndicator(
                            value: _currentProgressPercentage,
                            minHeight: 10,
                            backgroundColor: Colors.grey[700],
                            color: AppColors.successColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${(_currentProgressPercentage * 100).toStringAsFixed(1)}% Completed',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (currentGoalAchieved) ...[
                            const SizedBox(height: 20),
                            const Text(
                              'Goal Achieved! 🎉',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.successColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _currentGoalAmount = 0.0;
                                _currentSavedAmount = 0.0;
                              });
                              _saveData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Current Goal Reset!'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reset Current Goal'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: AppColors.textColor,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    color: currentTheme.cardColor,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Set New Current Goal',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _goalController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppColors.textColor),
                            decoration: InputDecoration(
                              labelText: 'Enter your new goal amount',
                              labelStyle: TextStyle(
                                color: AppColors.textColor.withOpacity(0.7),
                              ),
                              prefixText: _currencySymbol,
                              prefixStyle: const TextStyle(
                                color: AppColors.textColor,
                                fontSize: 18,
                              ),
                              filled: true,
                              fillColor: _isDarkMode
                                  ? AppColors.darkPrimaryColor
                                  : AppColors.primaryColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          ElevatedButton.icon(
                            onPressed: _setCurrentGoal,
                            icon: const Icon(Icons.star),
                            label: const Text('Set Current Goal'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentColor,
                              foregroundColor: AppColors.textColor,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    color: currentTheme.cardColor,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Manage Current Savings',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _addAmountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppColors.textColor),
                            decoration: InputDecoration(
                              labelText: 'Amount to add',
                              labelStyle: TextStyle(
                                color: AppColors.textColor.withOpacity(0.7),
                              ),
                              prefixText: _currencySymbol,
                              prefixStyle: const TextStyle(
                                color: AppColors.textColor,
                                fontSize: 18,
                              ),
                              filled: true,
                              fillColor: _isDarkMode
                                  ? AppColors.darkPrimaryColor
                                  : AppColors.primaryColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          ElevatedButton.icon(
                            onPressed: _addCurrentSavings,
                            icon: const Icon(Icons.add_circle),
                            label: const Text('Add Savings'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successColor,
                              foregroundColor: AppColors.textColor,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          ElevatedButton.icon(
                            onPressed: _useCurrentSavings,
                            icon: const Icon(Icons.remove_circle),
                            label: const Text('Used Savings'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: AppColors.textColor,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab 2: Daily Challenge
            SingleChildScrollView(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: currentTheme.cardColor,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        children: [
                          const Text(
                            'Set Your 100-Day Saving Challenge!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: _futureGoalAmountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppColors.textColor),
                            decoration: InputDecoration(
                              labelText: 'Target Amount (e.g., 100000)',
                              labelStyle: TextStyle(
                                color: AppColors.textColor.withOpacity(0.7),
                              ),
                              prefixText: _currencySymbol,
                              prefixStyle: const TextStyle(
                                color: AppColors.textColor,
                                fontSize: 18,
                              ),
                              filled: true,
                              fillColor: _isDarkMode
                                  ? AppColors.darkPrimaryColor
                                  : AppColors.primaryColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          ElevatedButton.icon(
                            onPressed: _setFutureGoal,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Start Challenge'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentColor,
                              foregroundColor: AppColors.textColor,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_futureGoalTargetAmount > 0) ...[
                    const SizedBox(height: 30),
                    Card(
                      color: currentTheme.cardColor,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          children: [
                            Text(
                              'Target: $_currencySymbol${_futureGoalTargetAmount.toStringAsFixed(2)} in 100 days',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Total Saved: $_currencySymbol${_currentFutureSavings.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                color: AppColors.textColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Mark off each day you save:',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // ✅ Responsiveness Fix:
                            // The grid now uses SliverGridDelegateWithMaxCrossAxisExtent,
                            // which automatically adjusts the number of columns based on screen width.
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent:
                                        120, // Max width of each item
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                              itemCount: _futureGoalTotalDays,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () =>
                                      _toggleFutureGoalDayCompletion(index),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _futureGoalCompletionStatus[index]
                                          ? AppColors.successColor
                                          : (_isDarkMode
                                                ? AppColors.darkPrimaryColor
                                                : AppColors.primaryColor),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            _futureGoalCompletionStatus[index]
                                            ? AppColors.successColor
                                            : AppColors.textColor.withOpacity(
                                                0.3,
                                              ),
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Day ${index + 1}',
                                            style: const TextStyle(
                                              color: AppColors.textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (_futureGoalDailyAmounts
                                              .isNotEmpty)
                                            Text(
                                              '$_currencySymbol${_futureGoalDailyAmounts[index].toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color:
                                                    _futureGoalCompletionStatus[index]
                                                    ? AppColors.cardColor
                                                    : AppColors.textColor
                                                          .withOpacity(0.8),
                                                fontSize: 10,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Tab 3: Settings
            SingleChildScrollView(
              padding: EdgeInsets.all(cardPadding),
              child: Card(
                color: currentTheme.cardColor,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: EdgeInsets.all(cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'App Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(
                            _isDarkMode
                                ? Icons.nightlight_round
                                : Icons.wb_sunny,
                            color: AppColors.textColor.withOpacity(0.7),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Dark Mode',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textColor,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: _isDarkMode,
                            onChanged: (value) {
                              setState(() {
                                _isDarkMode = value;
                              });
                              _saveData();
                            },
                            activeColor: AppColors.accentColor,
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.textColor),
                      // ✅ New: Currency Selection Option
                      Row(
                        children: [
                          Icon(
                            Icons.monetization_on,
                            color: AppColors.textColor.withOpacity(0.7),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Select Currency',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textColor,
                            ),
                          ),
                          const Spacer(),
                          DropdownButton<String>(
                            value: _selectedCurrencyCode,
                            dropdownColor: currentTheme.cardColor,
                            style: const TextStyle(
                              color: AppColors.textColor,
                              fontSize: 16,
                            ),
                            underline: Container(
                              height: 2,
                              color: AppColors.accentColor,
                            ),
                            items: _currencyOptions.keys
                                .map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      '$value (${_currencyOptions[value]})',
                                    ),
                                  );
                                })
                                .toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedCurrencyCode = newValue;
                                  _updateCurrencySymbol();
                                });
                                _saveData();
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.textColor),
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active,
                            color: AppColors.textColor.withOpacity(0.7),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Daily Reminders',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textColor,
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: _notificationsEnabled,
                            onChanged: (value) {
                              setState(() {
                                _notificationsEnabled = value;
                              });
                              _saveData();
                              if (_notificationsEnabled) {
                                _scheduleDailyNotification();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Daily reminders are ON!'),
                                  ),
                                );
                              } else {
                                _cancelAllNotifications();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Daily reminders are OFF.'),
                                  ),
                                );
                              }
                            },
                            activeColor: AppColors.accentColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
