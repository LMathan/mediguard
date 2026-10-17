import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/inventory_transaction.dart';
import '../../data/models/medicine.dart';
import '../../shared/providers/app_providers.dart';

class TransactionFlowScreen extends ConsumerStatefulWidget {
  final String? medicineId;
  final String? initialAction;
  final bool isScanMode;

  const TransactionFlowScreen({
    super.key,
    this.medicineId,
    this.initialAction,
    this.isScanMode = false,
  });

  @override
  ConsumerState<TransactionFlowScreen> createState() =>
      _TransactionFlowScreenState();
}

class _TransactionFlowScreenState extends ConsumerState<TransactionFlowScreen> {
  int _currentStep = 0;
  final _rfidScanController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  Medicine? _selectedMedicine;
  TransactionAction _action = TransactionAction.add;
  InventoryTransaction? _pendingTx;
  bool _isDoorCycleObserved = false;
  bool _isProcessing = false;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    if (widget.initialAction == 'remove') {
      _action = TransactionAction.remove;
    }
    if (widget.medicineId != null) {
      _loadMedicine(widget.medicineId!);
    }
  }

  void _loadMedicine(String id) {
    final list = ref.read(medicineListProvider).value ?? [];
    final med = list.where((m) => m.id == id).firstOrNull;
    if (med != null) {
      setState(() {
        _selectedMedicine = med;
        _currentStep = 1; // Skip tag scan
      });
    }
  }

  @override
  void dispose() {
    _rfidScanController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleRfidLookup() async {
    final uid = _rfidScanController.text.trim();
    if (uid.isEmpty) return;

    setState(() {
      _statusError = null;
    });

    final repo = ref.read(medicineRepositoryProvider);
    final med = await repo.getMedicineByRfid(uid);

    if (!mounted) return;

    if (med != null) {
      setState(() {
        _selectedMedicine = med;
        _currentStep = 1;
      });
    } else {
      // Unknown tag: offer to register
      final registerNew = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unknown RFID Tag'),
          content: Text(
            'No active medicine is associated with UID "$uid". Would you like to register this medicine?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Register Tag'),
            ),
          ],
        ),
      );

      if (registerNew == true && mounted) {
        context.push('/inventory/add');
      }
    }
  }

  Future<void> _createPending() async {
    if (_selectedMedicine == null) return;

    final qty = int.tryParse(_quantityController.text) ?? 1;
    if (qty <= 0) {
      setState(() {
        _statusError = 'Enter a valid quantity greater than zero';
      });
      return;
    }

    if (_action == TransactionAction.remove &&
        qty > _selectedMedicine!.quantity) {
      setState(() {
        _statusError =
            'Cannot remove $qty units: only ${_selectedMedicine!.quantity} in stock';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusError = null;
    });

    try {
      final tx = InventoryTransaction(
        id: '',
        medicineId: _selectedMedicine!.id,
        medicineName: _selectedMedicine!.name,
        action: _action,
        quantityChange: _action == TransactionAction.add ? qty : -qty,
        compartment: _selectedMedicine!.compartment,
        rfidUid: _selectedMedicine!.rfidUid,
        initiationMethod: widget.isScanMode ? 'rfid' : 'manual',
        confirmationMethod: 'app',
        status: TransactionStatus.pending,
        initiatedAt: DateTime.now(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final created = await ref
          .read(transactionsProvider.notifier)
          .startPending(tx);
      setState(() {
        _pendingTx = created;
        _currentStep = 2; // Move to compartment placement & door cycle step
      });
    } catch (e) {
      setState(() {
        _statusError = 'Error initiating transaction: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _simulateDoorCycle() {
    setState(() {
      _isDoorCycleObserved = true;
    });
  }

  Future<void> _completeConfirmation(bool confirmed) async {
    if (_pendingTx == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await ref
          .read(transactionsProvider.notifier)
          .confirm(
            _pendingTx!.id,
            confirmed,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: confirmed
                ? AppColors.statusNormal
                : AppColors.statusWarning,
            content: Text(
              confirmed
                  ? 'Inventory updated successfully.'
                  : 'Transaction cancelled. Inventory remains unchanged.',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _statusError = 'Error confirming transaction: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _action == TransactionAction.add
              ? 'Inbound Stocking Flow'
              : 'Dispense Medicine Flow',
        ),
        actions: [
          if (_pendingTx != null && _pendingTx!.isPending)
            TextButton(
              onPressed: _isProcessing
                  ? null
                  : () => _completeConfirmation(false),
              child: const Text(
                'Cancel Tx',
                style: TextStyle(color: AppColors.statusCritical),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stepper Progress Indicators
            Row(
              children: [
                _buildStepPill(step: 0, label: 'Identify Tag'),
                const Expanded(
                  child: Divider(color: AppColors.border, thickness: 2),
                ),
                _buildStepPill(step: 1, label: 'Verify Storage'),
                const Expanded(
                  child: Divider(color: AppColors.border, thickness: 2),
                ),
                _buildStepPill(step: 2, label: 'Confirm Transfer'),
              ],
            ),
            const SizedBox(height: 24),

            if (_statusError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusCriticalBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusError!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.statusCritical,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // STEP 0: SCAN OR LOOKUP RFID
            if (_currentStep == 0) ...[
              const Text(
                'Scan or Enter RFID UID',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hold the vial/box tag near the RFID reader, or enter the tag ID manually.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _rfidScanController,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  labelText: 'RFID UID',
                  hintText: 'e.g., E28011700000020',
                  prefixIcon: Icon(Icons.nfc_rounded),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handleRfidLookup,
                child: const Text('Lookup Medicine by Tag'),
              ),
            ],

            // STEP 1: VERIFY MEDICINE & QUANTITY
            if (_currentStep == 1 && _selectedMedicine != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedMedicine!.compartment.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color:
                                _selectedMedicine!.compartment ==
                                    CompartmentType.cold
                                ? AppColors.coldCompartment
                                : AppColors.normalCompartment,
                          ),
                        ),
                        Text(
                          'Current Stock: ${_selectedMedicine!.quantity}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedMedicine!.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Required Storage: ${_selectedMedicine!.requiredStorage.label}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quantity Input
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _action == TransactionAction.add
                      ? 'Quantity to Add (Units) *'
                      : 'Quantity to Dispense (Units) *',
                  prefixIcon: const Icon(Icons.format_list_numbered),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Transaction Audit Notes',
                  hintText:
                      'e.g., Dispensed for patient bed 4B / Restocked batch',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isProcessing ? null : _createPending,
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _action == TransactionAction.add
                            ? 'Initiate Inbound Placement'
                            : 'Initiate Outbound Removal',
                      ),
              ),
            ],

            // STEP 2: HARDWARE COMPARTMENT CYCLE & EXPLICIT CONFIRMATION
            if (_currentStep == 2 && _pendingTx != null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.mintSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.mintAccent),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.door_front_door_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Target: ${_pendingTx!.compartment.label}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _action == TransactionAction.add
                          ? 'Please open the ${_pendingTx!.compartment.label} door and place ${_pendingTx!.quantityChange.abs()} units inside.'
                          : 'Please open the ${_pendingTx!.compartment.label} door and take out ${_pendingTx!.quantityChange.abs()} units.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Door cycle simulator / indicator
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isDoorCycleObserved
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: _isDoorCycleObserved
                          ? AppColors.statusNormal
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isDoorCycleObserved
                            ? 'Reed switch door cycle detected'
                            : 'Awaiting compartment door open/close...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isDoorCycleObserved
                              ? AppColors.statusNormal
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (!_isDoorCycleObserved)
                      OutlinedButton(
                        onPressed: _simulateDoorCycle,
                        child: const Text('Sim Door Cycle'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.demoBannerBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.demoBannerBorder),
                ),
                child: const Text(
                  'Physical Safety Notice: A reed switch only detects door position. Stock change is registered as user-confirmed inventory.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.demoBannerText,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () => _completeConfirmation(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirm Physical Transfer Complete'),
              ),
              const SizedBox(height: 10),

              OutlinedButton(
                onPressed: _isProcessing
                    ? null
                    : () => _completeConfirmation(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.statusCritical,
                  side: const BorderSide(color: AppColors.statusCritical),
                ),
                child: const Text('Cancel & Revert Transaction'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepPill({required int step, required String label}) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;

    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isDone
              ? AppColors.statusNormal
              : isActive
              ? AppColors.primary
              : AppColors.border,
          child: isDone
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '${step + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : AppColors.textSecondary,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
