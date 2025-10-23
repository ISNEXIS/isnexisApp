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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo, Colors.deepPurple],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
                          'Multiplayer Setup',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          controller: _serverController,
                          label: 'Server URL',
                          hintText: 'http://localhost:5231',
                          keyboardType: TextInputType.url,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter the server URL';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _displayNameController,
                          label: 'Display Name',
                          hintText: 'Player',
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Create a new room'),
                          value: _createRoom,
                          onChanged: (value) {
                            setState(() {
                              _createRoom = value;
                            });
                          },
                        ),
                        if (_createRoom) ...[
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _roomNameController,
                            label: 'Room Name',
                            hintText: 'My Arena',
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Max players: ${_maxPlayersValue.toInt()}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Slider(
                            value: _maxPlayersValue,
                            onChanged: (value) {
                              setState(() {
                                _maxPlayersValue = value;
                              });
                            },
                            divisions: 2,
                            min: 2,
                            max: 4,
                            label: _maxPlayersValue.toInt().toString(),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(
                              'A 3-character room code will be generated for you to share.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _joinCodeController,
                            label: 'Room Code',
                            hintText: 'ABC',
                            textInputAction: TextInputAction.done,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 3,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp('[A-Za-z0-9]'),
                              ),
                            ],
                            validator: (value) {
                              final code = value?.trim().toUpperCase() ?? '';
                              if (code.isEmpty) {
                                return 'Enter the room code';
                              }
                              if (code.length != 3) {
                                return 'Code must be 3 letters or numbers';
                              }
                              return null;
                            },
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16.0),
                            child: LinearProgressIndicator(),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : widget.onCancel,
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: const Text('Continue'),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
        counterText: maxLength != null ? '' : null,
      ),
      validator: validator,
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
