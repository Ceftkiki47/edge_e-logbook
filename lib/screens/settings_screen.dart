import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../providers/lora_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_topbar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoadingDevices = false;
  List<dynamic> _edgeDevices = [];
  List<dynamic> _loraNodes = [];
  String? _selectedEcid;
  bool _isEcidLocked = false;
  final Set<String> _selectedLoraNodes = {};
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDevices();
    });
  }

  Future<void> _loadDevices({bool showLoadingUI = true}) async {
    final prov = context.read<LoraProvider>();
    if (showLoadingUI) {
      setState(() {
        _isLoadingDevices = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await prov.fetchAvailableDevices();
      setState(() {
        _edgeDevices = data['edge_computing'] ?? [];
        _loraNodes = data['lora_nodes'] ?? [];
        
        // Cek apakah savedEcid masih ada di daftar edge yang ditarik dari API
        final savedEcid = prov.savedEcid;
        final edgeExists = _edgeDevices.any((e) => e['nomorSeri'] == savedEcid);
        _selectedEcid = edgeExists ? savedEcid : null;
        _isEcidLocked = savedEcid != null;
        
        _selectedLoraNodes.clear();
        for (var node in _loraNodes) {
          if (node['isLockedByMe'] == true) {
            _selectedLoraNodes.add(node['nomorSeri']);
          }
        }
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted && showLoadingUI) setState(() => _isLoadingDevices = false);
    }
  }

  Future<void> _savePairing() async {
    if (_selectedEcid == null) return;
    final prov = context.read<LoraProvider>();
    setState(() => _isSaving = true);
    try {
      await prov.lockDevices(_selectedEcid!, _selectedLoraNodes.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil mengunci perangkat!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red));
      }
    } finally {
      await _loadDevices(showLoadingUI: false);
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmSave(LoraProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Penyimpanan'),
        content: const Text('Apakah Anda yakin ingin menyimpan perubahan konfigurasi Edge dan LoRa Node ini?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedEcid = prov.savedEcid;
                _selectedLoraNodes.clear();
                _selectedLoraNodes.addAll(prov.savedLoraNodes);
              });
            },
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _savePairing();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue, foregroundColor: Colors.white),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<LoraProvider>();
    final bool hasChanges = _selectedEcid != prov.savedEcid || !setEquals(_selectedLoraNodes, prov.savedLoraNodes.toSet());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppTopbar(title: 'Pengaturan Aplikasi'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(Icons.color_lens, 'Tampilan Aplikasi'),
                _buildCard([
                  SwitchListTile(
                    title: Text('Mode Gelap (Dark Mode)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    subtitle: Text('Gunakan tema warna gelap untuk kenyamanan mata', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    value: prov.isDarkMode,
                    activeColor: AppColors.blue,
                    onChanged: (val) => prov.toggleTheme(val),
                  ),
                ]),
                const SizedBox(height: 24),

                _buildSectionHeader(Icons.storage, 'Database & Penyimpanan Lokal'),
                _buildCard([
                  SwitchListTile(
                    title: Text('Auto-Save Data ke SQLite', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    subtitle: Text('Simpan otomatis setiap paket LoRa yang masuk', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    value: prov.autoSave,
                    activeColor: AppColors.blue,
                    onChanged: (val) => prov.setAutoSave(val),
                  ),
                ]),
                const SizedBox(height: 24),

                _buildSectionHeader(
                  Icons.link, 
                  'Pairing Perangkat (Edge & LoRa)',
                  trailing: TextButton.icon(
                    onPressed: _isLoadingDevices ? null : _loadDevices,
                    icon: _isLoadingDevices 
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh, size: 14),
                    label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                ),
                _buildCard([
                  if (_isLoadingDevices && _edgeDevices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text('Gagal memuat: $_errorMessage', style: const TextStyle(color: Colors.red)),
                          TextButton(onPressed: _loadDevices, child: const Text('Coba Lagi'))
                        ],
                      ),
                    )
                  else
                    IgnorePointer(
                      ignoring: _isLoadingDevices,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isLoadingDevices ? 0.5 : 1.0,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Pilih Edge Computing (Identitas Desktop Ini):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedEcid,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    fillColor: AppColors.surfaceAlt,
                                    filled: true,
                                  ),
                                  items: _edgeDevices.map<DropdownMenuItem<String>>((edge) {
                                    return DropdownMenuItem<String>(
                                      value: edge['nomorSeri'],
                                      child: Text('${edge['nomorSeri']} - ${edge['namaPerangkat']}', style: const TextStyle(fontSize: 13)),
                                    );
                                  }).toList(),
                                  onChanged: null, // Terkunci otomatis dari Web Admin
                                  hint: const Text('Terkunci dari Admin Web...', style: TextStyle(fontSize: 13)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('Pilih LoRa Node yang dikunci ke Edge ini:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          if (_loraNodes.isEmpty)
                            Text('Tidak ada LoRa Node yang tersedia.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
                          else
                            Container(
                              decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: _loraNodes.length > 10 ? 10 : _loraNodes.length,
                                separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.border),
                                itemBuilder: (context, index) {
                                  final node = _loraNodes[index];
                                  final sn = node['nomorSeri'] as String;
                                  return CheckboxListTile(
                                    title: Text('$sn - ${node['namaPerangkat']}', style: const TextStyle(fontSize: 13)),
                                    value: _selectedLoraNodes.contains(sn),
                                    activeColor: AppColors.blue,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedLoraNodes.add(sn);
                                        } else {
                                          _selectedLoraNodes.remove(sn);
                                        }
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: (_selectedEcid == null || _isSaving || !hasChanges) ? null : () => _confirmSave(prov),
                            icon: _isSaving 
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) 
                                : const Icon(Icons.save, size: 18),
                            label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Penguncian'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blue, 
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12)
                            ),
                          ),
                        ],
                      ),
                    ),
                ]),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.blue),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          if (trailing != null) ...[
            const Spacer(),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
