class ProtocolInfo {
  final String title;
  final String description;
  final String category;
  final bool isRecommended;
  final String? hardwareNote;

  ProtocolInfo({
    required this.title,
    required this.description,
    required this.category,
    this.isRecommended = false,
    this.hardwareNote,
  });
}

final List<ProtocolInfo> defaultProtocols = [
  ProtocolInfo(
    title: 'Auto Protocol (OBD-II)',
    description: 'Recommended — automatically detects protocol for 98% of vehicles',
    category: 'Standard Protocols',
    isRecommended: true,
  ),
  ProtocolInfo(
    title: 'ISO 15765-4 (CAN)',
    description: 'Most vehicles built from 2008+ onwards (High Speed Data)',
    category: 'Standard Protocols',
  ),
  ProtocolInfo(
    title: 'ISO 14230-4 (KWP2000)',
    description: 'Common in European & Asian vehicles (2000-2008)',
    category: 'Standard Protocols',
  ),
  ProtocolInfo(
    title: 'ISO 9141-2',
    description: 'Older European, Asian, and Chrysler vehicles (Pre-2004)',
    category: 'Standard Protocols',
  ),
  ProtocolInfo(
    title: 'SAE J1850 (PWM/VPW)',
    description: 'Older Ford (PWM) and General Motors (VPW) models',
    category: 'Standard Protocols',
  ),
  ProtocolInfo(
    title: 'Tesla Proprietary CAN',
    description: 'Direct Battery & Drive Unit CAN bus access for Model 3/Y/S/X',
    category: 'Advanced & Proprietary',
    hardwareNote: 'Requires Tesla Diagnostic OBD Harness adapter + STN1110/vLinker adapter',
  ),
  ProtocolInfo(
    title: 'Hybrid ECU Direct Protocol',
    description: 'High-voltage Battery & Inverter ECU diagnosis for Toyota/Lexus/Honda',
    category: 'Advanced & Proprietary',
    hardwareNote: 'Supports standard ELM327 v1.5 / vLinker MC+ adapters',
  ),
];
