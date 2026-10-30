import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/medicine.dart';
import '../../data/models/unregistered_medicine.dart';
import '../../shared/providers/app_providers.dart';

class AddEditMedicineScreen extends ConsumerStatefulWidget {
  final String? medicineId;
  final String? initialRfid;
  final String? unregisteredMedicineId;
  final String? initialCompartment;

  const AddEditMedicineScreen({
    super.key,
    this.medicineId,
    this.initialRfid,
    this.unregisteredMedicineId,
    this.initialCompartment,
  });

  @override
  ConsumerState<AddEditMedicineScreen> createState() =>
      _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends ConsumerState<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _strengthController = TextEditingController();
  final _dosageFormController = TextEditingController(text: 'Tablet');
  final _batchController = TextEditingController();
  final _rfidController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _minTempController = TextEditingController();
  final _maxTempController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  StorageRequirement _storageRequirement = StorageRequirement.normal;
  CompartmentType _compartment = CompartmentType.normal;
  bool _isLoading = false;
  String? _unregisteredId;

  @override
  void initState() {
    super.initState();
    _unregisteredId = widget.unregisteredMedicineId;
    if (widget.medicineId != null) {
      _loadExistingMedicine();
    } else {
      if (widget.initialRfid != null && widget.initialRfid!.isNotEmpty) {
        _rfidController.text = widget.initialRfid!;
      }
      if (widget.initialCompartment == 'cold') {
        _compartment = CompartmentType.cold;
        _storageRequirement = StorageRequirement.cold;
      } else if (widget.initialCompartment == 'normal') {
        _compartment = CompartmentType.normal;
        _storageRequirement = StorageRequirement.normal;
      }
    }
  }

  void _loadExistingMedicine() {
    final list = ref.read(medicineListProvider).value ?? [];
    final med = list.where((m) => m.id == widget.medicineId).firstOrNull;
    if (med != null) {
      _nameController.text = med.name;
      _brandController.text = med.brand ?? '';
      _strengthController.text = med.strength ?? '';
      _dosageFormController.text = med.dosageForm ?? 'Tablet';
      _batchController.text = med.batchNumber ?? '';
      _rfidController.text = med.rfidUid ?? '';
      _quantityController.text = med.quantity.toString();
      _notesController.text = med.notes ?? '';
      _storageRequirement = med.requiredStorage;
      _compartment = med.compartment;
      _expiryDate = med.expiryDate;
      if (med.minTemperatureC != null) {
        _minTempController.text = med.minTemperatureC.toString();
      }
      if (med.maxTemperatureC != null) {
        _maxTempController.text = med.maxTemperatureC.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _strengthController.dispose();
    _dosageFormController.dispose();
    _batchController.dispose();
    _rfidController.dispose();
    _quantityController.dispose();
    _minTempController.dispose();
    _maxTempController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _generateDemoRfid() {
    final hex = DateTime.now().millisecondsSinceEpoch
        .toRadixString(16)
        .toUpperCase();
    setState(() {
      _rfidController.text = 'E2801$hex';
      _unregisteredId = null;
    });
  }

  Future<void> _pickFromUnregisteredTags(BuildContext context) async {
    final list = ref.read(unregisteredMedicinesProvider).value ?? [];
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No unregistered tags waiting in queue. Scan a tag on your hardware unit first.',
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<UnregisteredMedicine>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Scanned RFID Tag',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap any detected tag to populate its UID and compartment:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final item = list[i];
                  final isCold = item.compartment.toLowerCase() == 'cold';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2FE),
                      child: Icon(
                        Icons.nfc_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.rfidUid,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Detected ${item.scanCount}x • ${isCold ? '❄️ Cold Zone' : '🌿 Normal Zone'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => Navigator.of(ctx).pop(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _rfidController.text = selected.rfidUid;
        _unregisteredId = selected.id;
        if (selected.compartment.toLowerCase() == 'cold') {
          _compartment = CompartmentType.cold;
          _storageRequirement = StorageRequirement.cold;
        } else if (selected.compartment.toLowerCase() == 'normal') {
          _compartment = CompartmentType.normal;
          _storageRequirement = StorageRequirement.normal;
        }
      });
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    // Check storage compatibility
    if (_storageRequirement == StorageRequirement.cold &&
        _compartment != CompartmentType.cold) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Storage Warning'),
          content: const Text(
            'This medicine requires cold storage (2-8°C), but the Normal compartment is selected. Are you sure you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Change to Cold Zone'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      );

      if (proceed != true) {
        setState(() {
          _compartment = CompartmentType.cold;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final minTemp =
          double.tryParse(_minTempController.text) ??
          (_storageRequirement == StorageRequirement.cold ? 2.0 : 15.0);
      final maxTemp =
          double.tryParse(_maxTempController.text) ??
          (_storageRequirement == StorageRequirement.cold ? 8.0 : 25.0);

      final medicine = Medicine(
        id: widget.medicineId ?? '',
        name: _nameController.text.trim(),
        brand: _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        strength: _strengthController.text.trim().isEmpty
            ? null
            : _strengthController.text.trim(),
        dosageForm: _dosageFormController.text.trim(),
        batchNumber: _batchController.text.trim().isEmpty
            ? null
            : _batchController.text.trim(),
        expiryDate: _expiryDate,
        rfidUid: _rfidController.text.trim().isEmpty
            ? null
            : _rfidController.text.trim(),
        requiredStorage: _storageRequirement,
        minTemperatureC: minTemp,
        maxTemperatureC: maxTemp,
        quantity: int.tryParse(_quantityController.text) ?? 1,
        compartment: _compartment,
        status: MedicineStatus.stored,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.medicineId != null) {
        await ref.read(medicineListProvider.notifier).updateMedicine(medicine);
      } else {
        await ref.read(medicineListProvider.notifier).addMedicine(medicine);
        // If this medicine was enrolled with an RFID tag, remove it from unregistered_medicines table
        if (medicine.rfidUid != null && medicine.rfidUid!.isNotEmpty) {
          await ref.read(unregisteredMedicinesProvider.notifier).consume(
                rfidUid: medicine.rfidUid!,
                unregisteredId: _unregisteredId,
              );
        }
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving medicine: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.medicineId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Medicine' : 'Register New Medicine'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Enrolling Unregistered Tag Banner (if enrolling)
              if (_unregisteredId != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    border: Border.all(color: const Color(0xFF16A34A)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF16A34A),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Enrolling Detected RFID Tag',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
                            Text(
                              'Tag UID: ${_rfidController.text}. It will be moved to your active inventory upon saving.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Section 1: Basic Information
              const Text(
                '1. Identification & Clinical Info',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Generic Name *',
                  hintText: 'e.g., Insulin Glargine, Amoxicillin',
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Medicine name is required'
                    : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand / Trade Name',
                        hintText: 'e.g., Lantus, Augmentin',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _strengthController,
                      decoration: const InputDecoration(
                        labelText: 'Strength',
                        hintText: 'e.g., 100 units/mL',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dosageFormController,
                      decoration: const InputDecoration(
                        labelText: 'Dosage Form',
                        hintText: 'e.g., Tablet, Vial, Pen',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _batchController,
                      decoration: const InputDecoration(
                        labelText: 'Batch / Lot #',
                        hintText: 'e.g., BAT-2026-99',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section 2: RFID UID Tagging
              const Text(
                '2. RFID Tag & Quantity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rfidController,
                      style: const TextStyle(fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        labelText: 'RFID UID Tag',
                        hintText: 'e.g., E28011700000025',
                        prefixIcon: Icon(Icons.nfc_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _generateDemoRfid,
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('Sim Tag'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Action to select from scanned unregistered tags
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _pickFromUnregisteredTags(context),
                  icon: const Icon(Icons.playlist_add_check, size: 18),
                  label: const Text('Select from Unregistered Scans'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock Quantity *',
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                      validator: (val) {
                        if (val == null || int.tryParse(val) == null) {
                          return 'Enter quantity';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickExpiryDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Expiry Date *',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(
                          DateFormat('yyyy-MM-dd').format(_expiryDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section 3: Storage Requirements
              const Text(
                '3. Storage Requirements & Compartment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<StorageRequirement>(
                initialValue: _storageRequirement,
                decoration: const InputDecoration(
                  labelText: 'Storage Classification',
                  prefixIcon: Icon(Icons.thermostat_outlined),
                ),
                items: StorageRequirement.values.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.label));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _storageRequirement = val;
                      if (val == StorageRequirement.cold) {
                        _compartment = CompartmentType.cold;
                        _minTempController.text = '2.0';
                        _maxTempController.text = '8.0';
                      } else if (val == StorageRequirement.normal) {
                        _compartment = CompartmentType.normal;
                        _minTempController.text = '15.0';
                        _maxTempController.text = '25.0';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<CompartmentType>(
                initialValue: _compartment,
                decoration: const InputDecoration(
                  labelText: 'Assigned Compartment',
                  prefixIcon: Icon(Icons.inbox_outlined),
                ),
                items: CompartmentType.values.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c.label));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _compartment = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minTempController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Min Temp (°C)',
                        hintText: 'e.g., 2.0',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxTempController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Max Temp (°C)',
                        hintText: 'e.g., 8.0',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Clinical Notes & Handling Instructions',
                  hintText:
                      'e.g., Protect from light, do not shake, dilute before infusion',
                ),
              ),
              const SizedBox(height: 28),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveMedicine,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEditing
                            ? 'Save Medicine Changes'
                            : 'Register Medicine in Registry',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
