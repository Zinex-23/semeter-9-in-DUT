import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Schedule model for persistent storage
class Schedule {
  final String id;
  String title;
  String description;
  String startTime;
  String endTime;
  List<String> days;
  bool isActive;
  List<String> devices;
  Map<String, String> actions;

  Schedule({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.days,
    required this.isActive,
    required this.devices,
    required this.actions,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'startTime': startTime,
        'endTime': endTime,
        'days': days,
        'isActive': isActive,
        'devices': devices,
        'actions': actions,
      };

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        startTime: json['startTime'],
        endTime: json['endTime'],
        days: List<String>.from(json['days']),
        isActive: json['isActive'],
        devices: List<String>.from(json['devices']),
        actions: Map<String, String>.from(json['actions']),
      );

  Schedule copyWith({
    String? id,
    String? title,
    String? description,
    String? startTime,
    String? endTime,
    List<String>? days,
    bool? isActive,
    List<String>? devices,
    Map<String, String>? actions,
  }) {
    return Schedule(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      days: days ?? this.days,
      isActive: isActive ?? this.isActive,
      devices: devices ?? this.devices,
      actions: actions ?? this.actions,
    );
  }
}

class DeviceManagerService extends ChangeNotifier {
  static final DeviceManagerService _instance =
      DeviceManagerService._internal();
  factory DeviceManagerService() => _instance;
  DeviceManagerService._internal() {
    _loadFromStorage();
  }

  // Air Conditioner Settings
  Map<String, double> _airConditionerTemperatures = {
    'Office AC Unit 1': 25.0,
    'Office AC Unit 2': 25.0,
  };

  Map<String, String> _airConditionerModes = {
    'Office AC Unit 1': 'Cool',
    'Office AC Unit 2': 'Cool',
  };

  Map<String, bool> _airConditionerStates = {
    'Office AC Unit 1': true,
    'Office AC Unit 2': true,
  };

  // Light Settings - using levels instead of percentage
  Map<String, String> _lightLevels = {
    'Office Lights': 'Level 2', // Level 1, Level 2, Level 3, Off
  };

  Map<String, bool> _lightStates = {
    'Office Lights': true,
  };

  // Schedules storage
  List<Schedule> _schedules = [];

  // Persistent storage methods
  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();

    // Load device states
    final acStatesJson = prefs.getString('ac_states');
    if (acStatesJson != null) {
      final decoded = jsonDecode(acStatesJson) as Map<String, dynamic>;
      _airConditionerStates = decoded.map((k, v) => MapEntry(k, v as bool));
    }

    final acTempsJson = prefs.getString('ac_temps');
    if (acTempsJson != null) {
      final decoded = jsonDecode(acTempsJson) as Map<String, dynamic>;
      _airConditionerTemperatures =
          decoded.map((k, v) => MapEntry(k, v as double));
    }

    final acModesJson = prefs.getString('ac_modes');
    if (acModesJson != null) {
      final decoded = jsonDecode(acModesJson) as Map<String, dynamic>;
      _airConditionerModes = decoded.map((k, v) => MapEntry(k, v as String));
    }

    final lightLevelsJson = prefs.getString('light_levels');
    if (lightLevelsJson != null) {
      final decoded = jsonDecode(lightLevelsJson) as Map<String, dynamic>;
      _lightLevels = decoded.map((k, v) => MapEntry(k, v as String));
    }

    final lightStatesJson = prefs.getString('light_states');
    if (lightStatesJson != null) {
      final decoded = jsonDecode(lightStatesJson) as Map<String, dynamic>;
      _lightStates = decoded.map((k, v) => MapEntry(k, v as bool));
    }

    // Load schedules
    final schedulesJson = prefs.getString('schedules');
    if (schedulesJson != null) {
      final decoded = jsonDecode(schedulesJson) as List<dynamic>;
      _schedules = decoded.map((json) => Schedule.fromJson(json)).toList();
    } else {
      // Initialize with default schedules if none exist
      _initializeDefaultSchedules();
    }

    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();

    // Save device states
    await prefs.setString('ac_states', jsonEncode(_airConditionerStates));
    await prefs.setString('ac_temps', jsonEncode(_airConditionerTemperatures));
    await prefs.setString('ac_modes', jsonEncode(_airConditionerModes));
    await prefs.setString('light_levels', jsonEncode(_lightLevels));
    await prefs.setString('light_states', jsonEncode(_lightStates));

    // Save schedules
    final schedulesJson = _schedules.map((s) => s.toJson()).toList();
    await prefs.setString('schedules', jsonEncode(schedulesJson));
  }

  void _initializeDefaultSchedules() {
    _schedules = [
      Schedule(
        id: '1',
        title: 'Work Hours',
        description: 'Optimal air quality during work time',
        startTime: '08:00',
        endTime: '17:00',
        days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        isActive: true,
        devices: ['Office AC Unit 1', 'Office AC Unit 2', 'Office Lights'],
        actions: {
          'Office AC Unit 1': 'Cool - 24°C',
          'Office AC Unit 2': 'Cool - 24°C',
          'Office Lights': 'Level 2 (7 bulbs)',
        },
      ),
      Schedule(
        id: '2',
        title: 'After Work Hours',
        description: 'Energy saving mode',
        startTime: '18:00',
        endTime: '07:59',
        days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        isActive: true,
        devices: ['Office AC Unit 1', 'Office AC Unit 2', 'Office Lights'],
        actions: {
          'Office AC Unit 1': 'Eco - 26°C',
          'Office AC Unit 2': 'Eco - 26°C',
          'Office Lights': 'Level 1 (5 bulbs)',
        },
      ),
    ];
  }

  // Available options
  final List<String> lightLevelOptions = [
    'Off',
    'Level 1',
    'Level 2',
    'Level 3'
  ];
  final List<String> acTemperatureOptions = [
    '18°C',
    '20°C',
    '22°C',
    '24°C',
    '26°C',
    '28°C'
  ];

  // Getters
  Map<String, double> get airConditionerTemperatures =>
      Map.from(_airConditionerTemperatures);
  Map<String, String> get airConditionerModes => Map.from(_airConditionerModes);
  Map<String, bool> get airConditionerStates => Map.from(_airConditionerStates);
  Map<String, String> get lightLevels => Map.from(_lightLevels);
  Map<String, bool> get lightStates => Map.from(_lightStates);
  List<Schedule> get schedules => List.from(_schedules);

  // Air Conditioner methods
  void updateAirConditionerTemperature(String deviceName, double temperature) {
    _airConditionerTemperatures[deviceName] = temperature;
    // Smart sync: Update schedule actions with new temperature but keep same mode
    _syncTemperatureToSchedules(deviceName, temperature);
    _saveToStorage();
    notifyListeners();
  }

  void updateAirConditionerMode(String deviceName, String mode) {
    _airConditionerModes[deviceName] = mode;
    // Smart sync: Update schedule actions with new mode but keep same temperature
    _syncModeToSchedules(deviceName, mode);
    _saveToStorage();
    notifyListeners();
  }

  void updateAirConditionerState(String deviceName, bool isOn) {
    _airConditionerStates[deviceName] = isOn;
    // Note: on/off state does NOT sync to schedules to preserve schedule integrity
    _saveToStorage();
    notifyListeners();
  }

  void updateLightState(String deviceName, bool isOn) {
    _lightStates[deviceName] = isOn;
    // Also update level based on on/off state
    if (!isOn) {
      _lightLevels[deviceName] = 'Off';
    } else if (_lightLevels[deviceName] == 'Off') {
      _lightLevels[deviceName] = 'Level 2'; // Default when turning on
    }
    _saveToStorage();
    notifyListeners();
  }

  double getAirConditionerTemperature(String deviceName) {
    return _airConditionerTemperatures[deviceName] ?? 25.0;
  }

  String getAirConditionerMode(String deviceName) {
    return _airConditionerModes[deviceName] ?? 'Cool';
  }

  bool getAirConditionerState(String deviceName) {
    return _airConditionerStates[deviceName] ?? true;
  }

  bool getLightState(String deviceName) {
    return _lightStates[deviceName] ?? true;
  }

  String getAirConditionerTemperatureString(String deviceName) {
    final temp = getAirConditionerTemperature(deviceName);
    return '${temp.toInt()}°C';
  }

  // Light methods
  void updateLightLevel(String deviceName, String level) {
    _lightLevels[deviceName] = level;
    _saveToStorage();
    notifyListeners();
  }

  String getLightLevel(String deviceName) {
    return _lightLevels[deviceName] ?? 'Level 2';
  }

  // Get light description for schedules
  String getLightDescription(String level) {
    switch (level) {
      case 'Off':
        return 'All lights off';
      case 'Level 1':
        return 'Dim - 5 bulbs on';
      case 'Level 2':
        return 'Medium - 7 bulbs on';
      case 'Level 3':
        return 'Bright - 9 bulbs on';
      default:
        return 'Medium - 7 bulbs on';
    }
  }

  // Get number of lights for each level
  int getLightCount(String level) {
    switch (level) {
      case 'Off':
        return 0;
      case 'Level 1':
        return 5;
      case 'Level 2':
        return 7;
      case 'Level 3':
        return 9;
      default:
        return 7;
    }
  }

  // Convert temperature string to double
  double temperatureFromString(String tempString) {
    return double.parse(tempString.replaceAll('°C', ''));
  }

  // Convert schedule action to device settings
  void applyScheduleAction(String device, String action) {
    if (device == 'Office AC Unit 1' || device == 'Office AC Unit 2') {
      // Parse new format: "Cool - 25°C"
      final parts = action.split(' - ');
      if (parts.length >= 2) {
        final mode = parts[0];
        final tempString = parts[1];

        // Update mode for specific device
        updateAirConditionerMode(device, mode);

        // Update temperature for specific device
        final tempMatch = RegExp(r'(\d+)°C').firstMatch(tempString);
        if (tempMatch != null) {
          final temp = double.parse(tempMatch.group(1)!);
          updateAirConditionerTemperature(device, temp);
        }
      } else if (action.contains('°C')) {
        // Fallback for old format
        final temp = double.parse(action.replaceAll(RegExp(r'[^0-9.]'), ''));
        updateAirConditionerTemperature(device, temp);
      }
    } else if (device.contains('Lights')) {
      // Convert old percentage-based actions to new level system
      if (action.contains('30%') || action.contains('Dim')) {
        updateLightLevel('Office Lights', 'Level 1');
      } else if (action.contains('70%') || action.contains('Medium')) {
        updateLightLevel('Office Lights', 'Level 2');
      } else if (action.contains('Full') || action.contains('100%')) {
        updateLightLevel('Office Lights', 'Level 3');
      } else if (action.contains('Off')) {
        updateLightLevel('Office Lights', 'Off');
      }
    }
  }

  // Get current settings for schedule display
  String getCurrentAirConditionerAction() {
    final temp = getAirConditionerTemperature('Office AC Unit 1');
    final mode = getAirConditionerMode('Office AC Unit 1');
    return '$mode - ${temp.toInt()}°C';
  }

  String getCurrentLightAction() {
    final level = getLightLevel('Office Lights');
    return getLightDescription(level);
  }

  // Smart sync methods - sync temperature and mode to schedules, but NOT on/off state
  void _syncTemperatureToSchedules(String deviceName, double temperature) {
    for (var schedule in _schedules) {
      if (schedule.actions.containsKey(deviceName)) {
        final currentAction = schedule.actions[deviceName]!;
        // Parse current action to get mode, update temperature
        final parts = currentAction.split(' - ');
        if (parts.length >= 2) {
          final mode = parts[0];
          schedule.actions[deviceName] = '$mode - ${temperature.toInt()}°C';
        }
      }
    }
  }

  void _syncModeToSchedules(String deviceName, String mode) {
    for (var schedule in _schedules) {
      if (schedule.actions.containsKey(deviceName)) {
        final currentAction = schedule.actions[deviceName]!;
        // Parse current action to get temperature, update mode
        final parts = currentAction.split(' - ');
        if (parts.length >= 2) {
          final tempString = parts[1];
          schedule.actions[deviceName] = '$mode - $tempString';
        }
      }
    }
  }

  // Schedule management methods
  void addSchedule(Schedule schedule) {
    _schedules.add(schedule);
    _saveToStorage();
    notifyListeners();
  }

  void updateSchedule(Schedule updatedSchedule) {
    final index = _schedules.indexWhere((s) => s.id == updatedSchedule.id);
    if (index != -1) {
      _schedules[index] = updatedSchedule;
      _saveToStorage();
      notifyListeners();
    }
  }

  void deleteSchedule(String scheduleId) {
    _schedules.removeWhere((s) => s.id == scheduleId);
    _saveToStorage();
    notifyListeners();
  }

  void toggleScheduleActive(String scheduleId) {
    final schedule = _schedules.firstWhere((s) => s.id == scheduleId);
    schedule.isActive = !schedule.isActive;
    _saveToStorage();
    notifyListeners();
  }

  // Generate unique ID for new schedules
  String _generateScheduleId() {
    final maxId = _schedules.isEmpty
        ? 0
        : _schedules
            .map((s) => int.tryParse(s.id) ?? 0)
            .reduce((a, b) => a > b ? a : b);
    return (maxId + 1).toString();
  }

  // Create new schedule with generated ID
  Schedule createNewSchedule({
    required String title,
    required String description,
    required String startTime,
    required String endTime,
    required List<String> days,
    required List<String> devices,
    required Map<String, String> actions,
  }) {
    return Schedule(
      id: _generateScheduleId(),
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      days: days,
      isActive: true,
      devices: devices,
      actions: actions,
    );
  }
}
