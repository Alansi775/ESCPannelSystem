/// ESC Configuration Models

class ESCConfig {
  final int maxRPM;
  final int currentLimit;
  final int pwmFreq;
  final int tempLimit;
  final int voltageCutoff;
  final int? cells;
  final String? mode;

  ESCConfig({
    required this.maxRPM,
    required this.currentLimit,
    required this.pwmFreq,
    required this.tempLimit,
    required this.voltageCutoff,
    this.cells,
    this.mode,
  });

  factory ESCConfig.fromJson(Map<String, dynamic> json) {
    return ESCConfig(
      maxRPM: json['maxRPM'] as int,
      currentLimit: json['currentLimit'] as int,
      pwmFreq: json['pwmFreq'] as int,
      tempLimit: json['tempLimit'] as int,
      voltageCutoff: json['voltageCutoff'] as int,
      cells: json['cells'] as int?,
      mode: json['mode'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'maxRPM': maxRPM,
    'currentLimit': currentLimit,
    'pwmFreq': pwmFreq,
    'tempLimit': tempLimit,
    'voltageCutoff': voltageCutoff,
    'cells': cells,
    'mode': mode,
  };

  ESCConfig copyWith({
    int? maxRPM,
    int? currentLimit,
    int? pwmFreq,
    int? tempLimit,
    int? voltageCutoff,
    int? cells,
    String? mode,
  }) {
    return ESCConfig(
      maxRPM: maxRPM ?? this.maxRPM,
      currentLimit: currentLimit ?? this.currentLimit,
      pwmFreq: pwmFreq ?? this.pwmFreq,
      tempLimit: tempLimit ?? this.tempLimit,
      voltageCutoff: voltageCutoff ?? this.voltageCutoff,
      cells: cells ?? this.cells,
      mode: mode ?? this.mode,
    );
  }
}

class ESCStatus {
  final bool isConnected;
  final String? portPath;
  final double? voltage;
  final double? current;
  final int? rpm;
  final int? temperature;

  ESCStatus({
    required this.isConnected,
    this.portPath,
    this.voltage,
    this.current,
    this.rpm,
    this.temperature,
  });

  factory ESCStatus.fromJson(Map<String, dynamic> json) {
    return ESCStatus(
      isConnected: json['isConnected'] as bool? ?? false,
      portPath: json['portPath'] as String?,
      voltage: json['voltage'] as double?,
      current: json['current'] as double?,
      rpm: json['rpm'] as int?,
      temperature: json['temperature'] as int?,
    );
  }
}

class SerialPort {
  final String path;
  final String manufacturer;
  final String serialNumber;
  final String description;

  SerialPort({
    required this.path,
    required this.manufacturer,
    required this.serialNumber,
    required this.description,
  });

  factory SerialPort.fromJson(Map<String, dynamic> json) {
    return SerialPort(
      path: json['path'] as String,
      manufacturer: json['manufacturer'] as String? ?? 'Unknown',
      serialNumber: json['serialNumber'] as String? ?? 'N/A',
      description: json['description'] as String? ?? 'Serial Device',
    );
  }

  @override
  String toString() => '$description ($path)';
}

class ESCProfile {
  final int id;
  final String name;
  final ESCConfig config;
  final DateTime createdAt;
  final DateTime updatedAt;

  ESCProfile({
    required this.id,
    required this.name,
    required this.config,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ESCProfile.fromJson(Map<String, dynamic> json) {
    return ESCProfile(
      id: json['id'] as int,
      name: json['name'] as String,
      config: ESCConfig.fromJson(json['config'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
