class HardwareProtocol {
  HardwareProtocol._();

  static const String serviceUuid = '0000FFE0-0000-1000-8000-00805F9B34FB';
  static const String characteristicUuid = '0000FFE1-0000-1000-8000-00805F9B34FB';

  static const String actionPress = 'press';
  static const String actionStop = 'stop';

  static const String uartBtnPrefix = 'BTN_';
  static const String uartBtPrefix = 'BT-';
  static const String uartPressPrefix = 'PRESS';
  static const String uartSetGridPrefix = 'SET_GRID';
}
