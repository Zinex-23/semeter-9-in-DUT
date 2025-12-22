import 'package:flutter/material.dart';
import '../services/device_manager.dart';

class SchedulingScreen extends StatefulWidget {
  const SchedulingScreen({super.key});

  @override
  State<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  late DeviceManagerService _deviceManager;

  @override
  void initState() {
    super.initState();
    _deviceManager = DeviceManagerService();
    // Listen to device manager changes for real-time sync
    _deviceManager.addListener(_onDeviceStateChanged);
  }

  @override
  void dispose() {
    _deviceManager.removeListener(_onDeviceStateChanged);
    super.dispose();
  }

  void _onDeviceStateChanged() {
    // Rebuild UI when device states change
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Responsive breakpoints
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebDemo = screenWidth > 800; // Web demo mode
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isWebDemo ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isWebDemo, isMobile),
              SizedBox(height: isWebDemo ? 32 : 24),
              _buildSchedulesList(isWebDemo, isMobile),
              SizedBox(height: isWebDemo ? 32 : 24),
              _buildAddScheduleButton(isWebDemo, isMobile),
              SizedBox(height: isWebDemo ? 32 : 80), // Extra space for mobile
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWebDemo, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isWebDemo ? 24 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isWebDemo ? 12 : 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: isWebDemo ? 28 : 24,
                ),
              ),
              SizedBox(width: isWebDemo ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Scheduling',
                      style: TextStyle(
                        fontSize: isWebDemo ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: isWebDemo ? 8 : 4),
                    Text(
                      'Automate your office environment',
                      style: TextStyle(
                        fontSize: isWebDemo ? 16 : 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesList(bool isWebDemo, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Schedules',
          style: TextStyle(
            fontSize: isWebDemo ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F2937),
          ),
        ),
        SizedBox(height: isWebDemo ? 16 : 12),

        // Responsive grid for web demo, column for mobile
        if (isWebDemo && _deviceManager.schedules.length > 1)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 2 : 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio:
                  MediaQuery.of(context).size.width > 1200 ? 1.4 : 2.0,
            ),
            itemCount: _deviceManager.schedules.length,
            itemBuilder: (context, index) => _buildScheduleCard(
                _deviceManager.schedules[index], isWebDemo, isMobile),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _deviceManager.schedules.length,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(bottom: isWebDemo ? 16 : 12),
              child: _buildScheduleCard(
                  _deviceManager.schedules[index], isWebDemo, isMobile),
            ),
          ),
      ],
    );
  }

  Widget _buildScheduleCard(Schedule schedule, bool isWebDemo, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isWebDemo ? 20 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: schedule.isActive
              ? const Color(0xFF6366F1)
              : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with title and action buttons
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.title,
                      style: TextStyle(
                        fontSize: isWebDemo ? 20 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isWebDemo ? 4 : 2),
                    Text(
                      schedule.description,
                      style: TextStyle(
                        fontSize: isWebDemo ? 14 : 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Edit and Delete buttons
              Flexible(
                flex: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _editSchedule(schedule),
                      icon: const Icon(Icons.edit),
                      iconSize: isWebDemo ? 20 : 16,
                      color: const Color(0xFF6366F1),
                      tooltip: 'Edit Schedule',
                      padding: EdgeInsets.all(isMobile ? 4 : 8),
                      constraints: BoxConstraints(
                        minWidth: isMobile ? 32 : 40,
                        minHeight: isMobile ? 32 : 40,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _deleteSchedule(schedule),
                      icon: const Icon(Icons.delete),
                      iconSize: isWebDemo ? 20 : 16,
                      color: Colors.red.shade400,
                      tooltip: 'Delete Schedule',
                      padding: EdgeInsets.all(isMobile ? 4 : 8),
                      constraints: BoxConstraints(
                        minWidth: isMobile ? 32 : 40,
                        minHeight: isMobile ? 32 : 40,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: isWebDemo ? 16 : 12),

          // Time and Days
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: isWebDemo ? 18 : 16,
                color: const Color(0xFF6366F1),
              ),
              SizedBox(width: isWebDemo ? 8 : 6),
              Text(
                '${schedule.startTime} - ${schedule.endTime}',
                style: TextStyle(
                  fontSize: isWebDemo ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),

          SizedBox(height: isWebDemo ? 12 : 8),

          // Days
          Wrap(
            spacing: isWebDemo ? 8 : 3,
            runSpacing: isWebDemo ? 8 : 4,
            children: schedule.days
                .map((day) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWebDemo ? 12 : 6,
                        vertical: isWebDemo ? 6 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: isWebDemo ? 12 : 9,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ))
                .toList(),
          ),

          SizedBox(height: isWebDemo ? 16 : 12),

          // Devices and Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Devices & Actions:',
                style: TextStyle(
                  fontSize: isWebDemo ? 14 : 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
              SizedBox(height: isWebDemo ? 8 : 4),
              ...schedule.actions.entries.map((entry) => Padding(
                    padding: EdgeInsets.only(bottom: isWebDemo ? 4 : 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _getDeviceIcon(entry.key),
                          size: isWebDemo ? 16 : 12,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: isWebDemo ? 8 : 4),
                        Expanded(
                          child: Text(
                            '${entry.key}: ${entry.value}',
                            style: TextStyle(
                              fontSize: isWebDemo ? 13 : 10,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),

          SizedBox(height: isWebDemo ? 16 : 12),

          // Status toggle
          Row(
            children: [
              Transform.scale(
                scale: isWebDemo ? 1.0 : 0.8,
                child: Switch(
                  value: schedule.isActive,
                  onChanged: (value) => _toggleScheduleStatus(schedule, value),
                  activeColor: const Color(0xFF6366F1),
                ),
              ),
              SizedBox(width: isWebDemo ? 8 : 4),
              Expanded(
                child: Text(
                  schedule.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: isWebDemo ? 14 : 11,
                    fontWeight: FontWeight.w500,
                    color: schedule.isActive
                        ? const Color(0xFF10B981)
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddScheduleButton(bool isWebDemo, bool isMobile) {
    return SizedBox(
      width: double.infinity,
      height: isWebDemo ? 56 : 48,
      child: ElevatedButton.icon(
        onPressed: _addCustomSchedule,
        icon: Icon(
          Icons.add,
          size: isWebDemo ? 24 : 20,
        ),
        label: Text(
          'Add Custom Schedule',
          style: TextStyle(
            fontSize: isWebDemo ? 16 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String device) {
    switch (device.toLowerCase()) {
      case 'air conditioner':
        return Icons.ac_unit;
      case 'lights':
        return Icons.lightbulb;
      default:
        return Icons.device_hub;
    }
  }

  void _toggleScheduleStatus(Schedule schedule, bool isActive) {
    _deviceManager.toggleScheduleActive(schedule.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Schedule ${isActive ? 'activated' : 'deactivated'}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _editSchedule(Schedule schedule) {
    _showScheduleDialog(schedule: schedule, isEditing: true);
  }

  void _deleteSchedule(Schedule schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Schedule',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${schedule.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _deviceManager.deleteSchedule(schedule.id);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Schedule deleted successfully',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.red.shade400,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addCustomSchedule() {
    _showScheduleDialog();
  }

  void _showScheduleDialog({Schedule? schedule, bool isEditing = false}) {
    final titleController = TextEditingController(text: schedule?.title ?? '');
    final descriptionController =
        TextEditingController(text: schedule?.description ?? '');
    TimeOfDay startTime = schedule != null
        ? TimeOfDay(
            hour: int.parse(schedule.startTime.split(':')[0]),
            minute: int.parse(schedule.startTime.split(':')[1]),
          )
        : const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = schedule != null
        ? TimeOfDay(
            hour: int.parse(schedule.endTime.split(':')[0]),
            minute: int.parse(schedule.endTime.split(':')[1]),
          )
        : const TimeOfDay(hour: 17, minute: 0);

    List<String> selectedDays = schedule?.days.toList() ?? [];
    Map<String, String> selectedActions = Map.from(schedule?.actions ?? {});

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isEditing ? 'Edit Schedule' : 'Add Custom Schedule',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width < 600
                  ? MediaQuery.of(context).size.width * 0.9
                  : MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Schedule Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF6366F1), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF6366F1), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time Selection
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Start Time'),
                          subtitle: Text(startTime.format(context)),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: startTime,
                            );
                            if (time != null) {
                              setDialogState(() {
                                startTime = time;
                              });
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: const Text('End Time'),
                          subtitle: Text(endTime.format(context)),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: endTime,
                            );
                            if (time != null) {
                              setDialogState(() {
                                endTime = time;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Days Selection
                  const Text(
                    'Days:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map((day) {
                      final isSelected = selectedDays.contains(day);
                      return FilterChip(
                        label: Text(day),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedDays.add(day);
                            } else {
                              selectedDays.remove(day);
                            }
                          });
                        },
                        selectedColor: const Color(0xFF6366F1).withOpacity(0.2),
                        checkmarkColor: const Color(0xFF6366F1),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Device Actions
                  const Text(
                    'Device Actions:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDeviceActionSelector(selectedActions, setDialogState),
                ],
              ),
            ),
          ),
          actions: [
            SizedBox(
              width: MediaQuery.of(context).size.width < 600 ? 80 : 100,
              height: MediaQuery.of(context).size.width < 600 ? 36 : 40,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width < 600 ? 80 : 100,
              height: MediaQuery.of(context).size.width < 600 ? 36 : 40,
              child: ElevatedButton(
                onPressed: () {
                  if (titleController.text.isEmpty || selectedDays.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all required fields'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final newSchedule = Schedule(
                    id: schedule?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text,
                    description: descriptionController.text,
                    startTime:
                        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                    endTime:
                        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                    days: selectedDays,
                    isActive: schedule?.isActive ?? true,
                    devices: selectedActions.keys.toList(),
                    actions: selectedActions,
                  );

                  if (isEditing) {
                    _deviceManager.updateSchedule(newSchedule);
                  } else {
                    _deviceManager.addSchedule(newSchedule);
                  }

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? 'Schedule updated successfully'
                            : 'Schedule created successfully',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFF6366F1),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isEditing ? 'Update' : 'Create',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceActionSelector(
      Map<String, String> selectedActions, StateSetter setDialogState) {
    final availableDevices = [
      'Office AC Unit 1',
      'Office AC Unit 2',
      'Office Lights',
    ];

    final availableActions = {
      'Office Lights': [
        'Level 3 (9 bulbs)',
        'Level 2 (7 bulbs)',
        'Level 1 (5 bulbs)',
        'Off',
      ],
    };

    return Column(
      children: availableDevices.map((device) {
        final isSelected = selectedActions.containsKey(device);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Row(
              children: [
                Icon(_getDeviceIcon(device), size: 20),
                const SizedBox(width: 8),
                Text(device),
                const Spacer(),
                Switch(
                  value: isSelected,
                  onChanged: (value) {
                    setDialogState(() {
                      if (value) {
                        if (device == 'Office AC Unit 1' ||
                            device == 'Office AC Unit 2') {
                          selectedActions[device] = 'Cool - 25°C'; // Default
                        } else {
                          selectedActions[device] =
                              availableActions[device]?.first ?? 'Off';
                        }
                      } else {
                        selectedActions.remove(device);
                      }
                    });
                  },
                  activeColor: const Color(0xFF6366F1),
                ),
              ],
            ),
            children: isSelected
                ? [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: (device == 'Office AC Unit 1' ||
                              device == 'Office AC Unit 2')
                          ? _buildAirConditionerControls(
                              device, selectedActions, setDialogState)
                          : _buildSimpleDropdown(
                              device,
                              availableActions[device] ?? ['Off'],
                              selectedActions,
                              setDialogState),
                    ),
                  ]
                : [],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAirConditionerControls(String device,
      Map<String, String> selectedActions, StateSetter setDialogState) {
    // Parse current values from action string
    final currentAction = selectedActions[device] ?? 'Cool - 25°C';
    final parts = currentAction.split(' - ');
    final currentMode = parts.isNotEmpty ? parts[0] : 'Cool';
    final tempMatch = RegExp(r'(\d+)°C').firstMatch(currentAction);
    final currentTemp = tempMatch != null ? int.parse(tempMatch.group(1)!) : 25;

    return Column(
      children: [
        // Temperature Control
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Temperature',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${currentTemp}°C',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                IconButton(
                  onPressed: currentTemp < 30
                      ? () {
                          setDialogState(() {
                            final newTemp = currentTemp + 1;
                            selectedActions[device] =
                                '$currentMode - ${newTemp}°C';
                          });
                        }
                      : null,
                  icon: const Icon(Icons.add),
                  iconSize: 20,
                  color: const Color(0xFF6366F1),
                ),
                IconButton(
                  onPressed: currentTemp > 16
                      ? () {
                          setDialogState(() {
                            final newTemp = currentTemp - 1;
                            selectedActions[device] =
                                '$currentMode - ${newTemp}°C';
                          });
                        }
                      : null,
                  icon: const Icon(Icons.remove),
                  iconSize: 20,
                  color: const Color(0xFF6366F1),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Mode Selection
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mode',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButton<String>(
                value: ['Heat', 'Cool', 'Eco', 'Dry'].contains(currentMode)
                    ? currentMode
                    : 'Cool',
                isExpanded: true,
                underline: const SizedBox(),
                items: ['Heat', 'Cool', 'Eco', 'Dry'].map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(mode),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() {
                      selectedActions[device] = '$value - ${currentTemp}°C';
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimpleDropdown(String device, List<String> actions,
      Map<String, String> selectedActions, StateSetter setDialogState) {
    return DropdownButtonFormField<String>(
      value: actions.contains(selectedActions[device])
          ? selectedActions[device]
          : actions.first,
      decoration: InputDecoration(
        labelText: 'Select Action',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: actions.map((action) {
        return DropdownMenuItem(
          value: action,
          child: Text(action),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setDialogState(() {
            selectedActions[device] = value;
          });
        }
      },
    );
  }
}
