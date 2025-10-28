import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/player_api_client.dart';

class MultiplayerSetupResult {
  final String baseUrl;
  final int roomId;
  final int playerId;
  final String displayName;
  final String joinCode;
  final bool createdRoom;
  final int maxPlayers;

  const MultiplayerSetupResult({
    required this.baseUrl,
    required this.roomId,
    required this.playerId,
    required this.displayName,
    required this.joinCode,
    required this.createdRoom,
    required this.maxPlayers,
  });
}

class MultiplayerSetupScreen extends StatefulWidget {
  final ValueChanged<MultiplayerSetupResult> onContinue;
  final VoidCallback onCancel;

  const MultiplayerSetupScreen({
    super.key,
    required this.onContinue,
    required this.onCancel,
  });

  @override
  State<MultiplayerSetupScreen> createState() => _MultiplayerSetupScreenState();
}

class _MultiplayerSetupScreenState extends State<MultiplayerSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _serverController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _joinCodeController;
  late final TextEditingController _roomNameController;
  double _maxPlayersValue = 4;

  String? _errorMessage;
  bool _isLoading = false;
  bool _createRoom = false;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(text: 'http://localhost:5231');
    _displayNameController = TextEditingController();
    _joinCodeController = TextEditingController();
    _roomNameController = TextEditingController();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _displayNameController.dispose();
    _joinCodeController.dispose();
    _roomNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🌐 MULTIPLAYER 🌐',
          style: TextStyle(
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: const Color(0xFF0F380F),
        foregroundColor: const Color(0xFF9BBC0F),
        iconTheme: const IconThemeData(color: Color(0xFF9BBC0F)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F380F), Color(0xFF306230)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF9BBC0F),
                  border: Border.all(color: const Color(0xFF0F380F), width: 5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '◆ ONLINE MODE ◆',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F380F),
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildRetroTextField(
                          controller: _serverController,
                          label: 'SERVER URL',
                          hintText: 'http://localhost:5231',
                        ),
                        const SizedBox(height: 16),
                        _buildRetroTextField(
                          controller: _displayNameController,
                          label: 'PLAYER NAME',
                          hintText: 'Player',
                        ),
                        const SizedBox(height: 16),
                        _buildRetroToggle(
                          label: 'CREATE NEW ROOM',
                          value: _createRoom,
                          onChanged: (value) {
                            setState(() {
                              _createRoom = value;
                            });
                          },
                        ),
                        if (_createRoom) ...[
                          const SizedBox(height: 16),
                          _buildRetroTextField(
                            controller: _roomNameController,
                            label: 'ROOM NAME',
                            hintText: 'My Arena',
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF306230),
                              border: Border.all(color: const Color(0xFF0F380F), width: 3),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'MAX PLAYERS: ${_maxPlayersValue.toInt()}',
                                  style: const TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF9BBC0F),
                                  ),
                                ),
                                SliderTheme(
                                  data: SliderThemeData(
                                    activeTrackColor: const Color(0xFF9BBC0F),
                                    inactiveTrackColor: const Color(0xFF0F380F),
                                    thumbColor: const Color(0xFF9BBC0F),
                                    overlayColor: const Color(0xFF9BBC0F).withOpacity(0.2),
                                    trackHeight: 8,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                                  ),
                                  child: Slider(
                                    value: _maxPlayersValue,
                                    onChanged: (value) {
                                      setState(() {
                                        _maxPlayersValue = value;
                                      });
                                    },
                                    divisions: 2,
                                    min: 2,
                                    max: 4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              'A 3-CHAR CODE WILL BE GENERATED',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 11,
                                color: Color(0xFF306230),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          _buildRetroTextField(
                            controller: _joinCodeController,
                            label: 'ROOM CODE',
                            hintText: 'ABC',
                            maxLength: 3,
                            uppercase: true,
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3333),
                              border: Border.all(color: const Color(0xFF0F380F), width: 3),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (_isLoading)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            height: 8,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF0F380F), width: 3),
                            ),
                            child: const LinearProgressIndicator(
                              backgroundColor: Color(0xFF306230),
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F380F)),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildRetroButton(
                                label: 'CANCEL',
                                onPressed: _isLoading ? null : widget.onCancel,
                                isPrimary: false,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildRetroButton(
                                label: 'START',
                                onPressed: _isLoading ? null : _submit,
                                isPrimary: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRetroTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    int? maxLength,
    bool uppercase = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Courier',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F380F),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF0F380F), width: 3),
          ),
          child: TextFormField(
            controller: controller,
            maxLength: maxLength,
            textCapitalization: uppercase ? TextCapitalization.characters : TextCapitalization.none,
            inputFormatters: uppercase
                ? [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))]
                : null,
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F380F),
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'Courier',
                color: const Color(0xFF0F380F).withOpacity(0.4),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
              counterText: '',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'REQUIRED!';
              }
              if (maxLength != null && value.length != maxLength) {
                return 'MUST BE $maxLength CHARS';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRetroToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF0F380F) : const Color(0xFF306230),
          border: Border.all(color: const Color(0xFF0F380F), width: 3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: value ? const Color(0xFF9BBC0F) : const Color(0xFF0F380F),
              ),
            ),
            Container(
              width: 50,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF9BBC0F), width: 2),
              ),
              child: Align(
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.all(1),
                  color: const Color(0xFF9BBC0F),
                  child: Center(
                    child: Text(
                      value ? 'Y' : 'N',
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F380F),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetroButton({
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
  }) {
    final isEnabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: !isEnabled
              ? const Color(0xFF306230)
              : (isPrimary ? const Color(0xFF0F380F) : const Color(0xFF9BBC0F)),
          border: Border.all(color: const Color(0xFF0F380F), width: 4),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: !isEnabled
                  ? const Color(0xFF0F380F).withOpacity(0.5)
                  : (isPrimary ? const Color(0xFF9BBC0F) : const Color(0xFF0F380F)),
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }


  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final baseUrl = _serverController.text.trim();
    final displayName = _displayNameController.text.trim();

    if (displayName.isEmpty) {
      setState(() {
        _errorMessage = 'Display name cannot be empty.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final api = PlayerApiClient(baseUrl: baseUrl);
      RoomJoinResult result;
      bool createdRoom;

      if (_createRoom) {
        result = await api.hostRoom(
          displayName: displayName,
          roomName: _roomNameController.text,
          maxPlayers: _maxPlayersValue.toInt(),
        );
        createdRoom = true;
        _joinCodeController.text = result.room.joinCode;
      } else {
        result = await api.joinRoomByCode(
          joinCode: _joinCodeController.text,
          displayName: displayName,
        );
        createdRoom = false;
      }

      widget.onContinue(
        MultiplayerSetupResult(
          baseUrl: baseUrl,
          roomId: result.room.id,
          playerId: result.playerId,
          displayName: result.playerName,
          joinCode: result.room.joinCode,
          createdRoom: createdRoom,
          maxPlayers: result.room.maxPlayers,
        ),
      );
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      setState(() {
        _errorMessage =
            'Unable to contact the server. Please check the URL and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
