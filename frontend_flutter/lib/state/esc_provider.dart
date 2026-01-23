/// App State Management using Provider

import 'package:flutter/material.dart';
import '../models/esc_models.dart';
import '../services/backend_api.dart';

class ESCProvider extends ChangeNotifier {
  // Connection state
  bool _isConnected = false;
  String? _connectedPort;
  List<SerialPort> _availablePorts = [];

  // Configuration state
  ESCConfig? _currentConfig;
  ESCConfig? _pendingConfig;

  // Profiles state
  List<ESCProfile> _profiles = [];

  // UI state
  bool _isLoading = false;
  String? _errorMessage;
  String _currentLanguage = 'EN';

  // ESC Specifications
  static const int minBatteryCells = 2;
  static const int maxBatteryCells = 30;
  static const int standardCellsThreshold = 12;
  static const double nominalVoltagePerCell = 3.7; // LiPo nominal
  static const double escMaxVoltage = 60.0; // ESC max voltage capability

  // Wizard Configuration State - Persistent across steps
  int _wizardBatteryCells = 4;
  String _wizardMotorType = 'BLDC';
  int _wizardPolePairs = 4;
  int _wizardKV = 1000;
  int _wizardMaxCurrent = 50;
  int _wizardMaxRPM = 5000;
  String _wizardSensorMode = 'Sensorless';
  String _wizardControlMode = 'Throttle';
  bool _wizardBrakeEnabled = false;
  int _wizardPWMFreq = 16;
  int _wizardMaxTemp = 60;
  int _wizardOvercurrent = 100;

  // Battery configuration cache
  int _selectedBatteryCells = 4;
  bool _isBatteryValid = true;
  
  // Additional configuration properties for saveConfig
  String? _selectedProfile;
  String? _escType;
  int _cellCount = 4;
  String? _sensorType;
  int _maxRPM = 0;
  int _motorKV = 0;
  int _motorPoles = 0;
  int _currentLimit = 0;
  int _pwmFrequency = 0;

  // Getters
  bool get isConnected => _isConnected;
  String? get connectedPort => _connectedPort;
  List<SerialPort> get availablePorts => _availablePorts;
  ESCConfig? get currentConfig => _currentConfig;
  ESCConfig? get pendingConfig => _pendingConfig;
  List<ESCProfile> get profiles => _profiles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentLanguage => _currentLanguage;
  
  int get selectedBatteryCells => _selectedBatteryCells;
  bool get isBatteryValid => _isBatteryValid;
  bool get isIndustrialBattery => _selectedBatteryCells >= (standardCellsThreshold + 1);
  double get estimatedVoltage => _selectedBatteryCells * nominalVoltagePerCell;
  
  // Configuration properties for saveConfig
  String? get selectedProfile => _selectedProfile;
  String? get escType => _escType;
  int get cellCount => _cellCount;
  String? get sensorType => _sensorType;
  int get maxRPM => _maxRPM;
  int get motorKV => _motorKV;
  int get motorPoles => _motorPoles;
  int get currentLimit => _currentLimit;
  int get pwmFrequency => _pwmFrequency;

  // Wizard config getters
  int get wizardBatteryCells => _wizardBatteryCells;
  String get wizardMotorType => _wizardMotorType;
  int get wizardPolePairs => _wizardPolePairs;
  int get wizardKV => _wizardKV;
  int get wizardMaxCurrent => _wizardMaxCurrent;
  int get wizardMaxRPM => _wizardMaxRPM;
  String get wizardSensorMode => _wizardSensorMode;
  String get wizardControlMode => _wizardControlMode;
  bool get wizardBrakeEnabled => _wizardBrakeEnabled;
  int get wizardPWMFreq => _wizardPWMFreq;
  int get wizardMaxTemp => _wizardMaxTemp;
  int get wizardOvercurrent => _wizardOvercurrent;

  Map<String, dynamic> get wizardConfig => {
    'batteryCells': _wizardBatteryCells,
    'motorType': _wizardMotorType,
    'polePairs': _wizardPolePairs,
    'kvRating': _wizardKV,
    'maxCurrent': _wizardMaxCurrent,
    'maxRPM': _wizardMaxRPM,
    'sensorMode': _wizardSensorMode,
    'controlMode': _wizardControlMode,
    'brakeEnabled': _wizardBrakeEnabled,
    'pwmFrequency': _wizardPWMFreq,
    'maxTemp': _wizardMaxTemp,
    'overcurrentLimit': _wizardOvercurrent,
  };

  // Wizard config setters
  void setWizardBatteryCells(int cells) {
    validateBatteryCells(cells);
    _wizardBatteryCells = cells;
    notifyListeners();
  }

  void setWizardMotorType(String type) {
    _wizardMotorType = type;
    notifyListeners();
  }

  void setWizardPolePairs(int pairs) {
    _wizardPolePairs = pairs;
    notifyListeners();
  }

  void setWizardKV(int kv) {
    _wizardKV = kv;
    notifyListeners();
  }

  void setWizardMaxCurrent(int current) {
    _wizardMaxCurrent = current;
    notifyListeners();
  }

  void setWizardMaxRPM(int rpm) {
    _wizardMaxRPM = rpm;
    notifyListeners();
  }

  void setWizardSensorMode(String mode) {
    _wizardSensorMode = mode;
    notifyListeners();
  }

  void setWizardControlMode(String mode) {
    _wizardControlMode = mode;
    notifyListeners();
  }

  void setWizardBrakeEnabled(bool enabled) {
    _wizardBrakeEnabled = enabled;
    notifyListeners();
  }

  void setWizardPWMFreq(int freq) {
    _wizardPWMFreq = freq;
    notifyListeners();
  }

  void setWizardMaxTemp(int temp) {
    _wizardMaxTemp = temp;
    notifyListeners();
  }

  void setWizardOvercurrent(int limit) {
    _wizardOvercurrent = limit;
    notifyListeners();
  }

  void resetWizardConfig() {
    _wizardBatteryCells = 4;
    _wizardMotorType = 'BLDC';
    _wizardPolePairs = 4;
    _wizardKV = 1000;
    _wizardMaxCurrent = 50;
    _wizardMaxRPM = 5000;
    _wizardSensorMode = 'Sensorless';
    _wizardControlMode = 'Throttle';
    _wizardBrakeEnabled = false;
    _wizardPWMFreq = 16;
    _wizardMaxTemp = 60;
    _wizardOvercurrent = 100;
    notifyListeners();
  }

  void setLanguage(String language) {
    _currentLanguage = language;
    notifyListeners();
  }


  // Battery validation
  bool validateBatteryCells(int cells) {
    if (cells < minBatteryCells || cells > maxBatteryCells) {
      _setError('Battery cells must be between ${minBatteryCells}S and ${maxBatteryCells}S');
      _isBatteryValid = false;
      return false;
    }

    final voltage = cells * nominalVoltagePerCell;
    if (voltage > escMaxVoltage) {
      _setError('Voltage ${voltage.toStringAsFixed(1)}V exceeds ESC max capability (${escMaxVoltage}V)');
      _isBatteryValid = false;
      return false;
    }

    _selectedBatteryCells = cells;
    _isBatteryValid = true;
    _clearError();
    notifyListeners();
    return true;
  }

  // Get configuration limits based on battery selection
  Map<String, dynamic> getConfigLimitsForBattery(int cells) {
    final isIndustrial = cells >= (standardCellsThreshold + 1);
    
    return {
      'maxCurrent': isIndustrial ? 200 : 100,
      'maxRPM': isIndustrial ? 100000 : 50000,
      'maxTemp': isIndustrial ? 80 : 60,
      'voltageNominal': cells * nominalVoltagePerCell,
      'isIndustrial': isIndustrial,
    };
  }

  // Load available ports
  Future<void> loadAvailablePorts() async {
    try {
      _setLoading(true);
      _clearError();
      _availablePorts = await BackendAPI.getAvailablePorts();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Connect to ESC
  Future<void> connectToESC(String portPath) async {
    try {
      _setLoading(true);
      _clearError();
      await BackendAPI.connectESC(portPath);
      _isConnected = true;
      _connectedPort = portPath;
      await loadCurrentConfig();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Disconnect from ESC
  Future<void> disconnectFromESC() async {
    try {
      _setLoading(true);
      _clearError();
      await BackendAPI.disconnectESC();
      _isConnected = false;
      _connectedPort = null;
      _currentConfig = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Load current config from ESC
  Future<void> loadCurrentConfig() async {
    try {
      _setLoading(true);
      _clearError();
      _currentConfig = await BackendAPI.getConfig();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Generate auto config
  Future<void> generateAutoConfig(int cells, String mode) async {
    try {
      _setLoading(true);
      _clearError();
      _pendingConfig = await BackendAPI.generateAutoConfig(cells, mode);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Apply config to ESC (legacy)
  Future<void> applyConfigLegacy(ESCConfig config) async {
    try {
      _setLoading(true);
      _clearError();
      await BackendAPI.applyConfigLegacy(config);
      _currentConfig = config;
      _pendingConfig = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Save profile
  Future<int> saveProfile(String profileName, ESCConfig config) async {
    try {
      _setLoading(true);
      _clearError();
      final id = await BackendAPI.saveProfile(profileName, config);
      await loadProfiles();
      return id;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Load all profiles
  Future<void> loadProfiles() async {
    try {
      _setLoading(true);
      _clearError();
      _profiles = await BackendAPI.getProfiles();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Load profile by ID
  Future<void> loadProfileById(int id) async {
    try {
      _setLoading(true);
      _clearError();
      final profile = await BackendAPI.getProfileById(id);
      _pendingConfig = profile.config;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Update pending config
  void updatePendingConfig(ESCConfig config) {
    _pendingConfig = config;
    notifyListeners();
  }
  
  // Configuration property setters
  void setSelectedProfile(String? profile) {
    _selectedProfile = profile;
    notifyListeners();
  }
  
  void setEscType(String? type) {
    _escType = type;
    notifyListeners();
  }
  
  void setCellCount(int count) {
    _cellCount = count;
    notifyListeners();
  }
  
  void setSensorType(String? type) {
    _sensorType = type;
    notifyListeners();
  }
  
  void setMaxRPM(int rpm) {
    _maxRPM = rpm;
    notifyListeners();
  }
  
  void setMotorKV(int kv) {
    _motorKV = kv;
    notifyListeners();
  }
  
  void setMotorPoles(int poles) {
    _motorPoles = poles;
    notifyListeners();
  }
  
  void setCurrentLimit(int limit) {
    _currentLimit = limit;
    notifyListeners();
  }
  
  void setPWMFrequency(int freq) {
    _pwmFrequency = freq;
    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool value) {
    _isLoading = value;
  }

  void _setError(String message) {
    _errorMessage = message;
  }

  void _clearError() {
    _errorMessage = null;
  }
}
