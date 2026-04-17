// ============================================================
// PAYROLL DUMMY DATA SEEDER
// Seeds monthly_deductions + users.salary so payroll
// deductions can be tested end-to-end.
//
// HOW TO USE:
//   1. Add a debug button anywhere in your app:
//        ElevatedButton(
//          onPressed: () => PayrollDummySeeder().seedAll(),
//          child: Text('Seed Payroll Test Data'),
//        )
//   2. Tap it once — check Firestore to confirm data.
//   3. Run payroll for March 2026 → verify net pay is correct.
//   4. Call PayrollDummySeeder().clearAll() to clean up.
//
// EXPECTED RESULTS after seeding + running payroll March 2026:
//
//  Employee        Salary    Missed  Deduct%  Deduction   Bonus    Net (approx)
//  ──────────────────────────────────────────────────────────────────────────
//  test_emp_001    80,000    2       5%       8,000       0        72,000
//  test_emp_002    120,000   0       5%       0           9,600    129,600  (bonus: 8% × 120k)
//  test_emp_003    60,000    1       5%       3,000       0        57,000
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class PayrollDummySeeder {
  final _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────
  // SEED ALL
  // ─────────────────────────────────────────────────────────────
  Future<void> seedAll() async {
    print('🌱 Seeding payroll dummy data...');
    await Future.wait([
      _seedUsers(),
      _seedMonthlyDeductions(),
    ]);
    print('✅ Seeding complete. Run payroll for March 2026 to test.');
  }

  // ─────────────────────────────────────────────────────────────
  // SEED USERS  (salary field is what payroll reads)
  // ─────────────────────────────────────────────────────────────
  Future<void> _seedUsers() async {
    final users = [
      {
        'id':          'test_emp_001',
        'name':        'Ahmed Raza',
        'email':       'ahmed@test.com',
        'role':        'employee',
        'designation': 'Software Engineer',
        'salary':      80000.0,
      },
      {
        'id':          'test_emp_002',
        'name':        'Sana Malik',
        'email':       'sana@test.com',
        'role':        'employee',
        'designation': 'Product Designer',
        'salary':      120000.0,
      },
      {
        'id':          'test_emp_003',
        'name':        'Bilal Khan',
        'email':       'bilal@test.com',
        'role':        'employee',
        'designation': 'QA Engineer',
        'salary':      60000.0,
      },
    ];

    for (final u in users) {
      final id = u['id'] as String;
      final data = Map<String, dynamic>.from(u)..remove('id');
      await _db.collection('users').doc(id).set(data, SetOptions(merge: true));
      print('  👤 Seeded user: ${u['name']} (salary: PKR ${u['salary']})');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SEED MONTHLY DEDUCTIONS  (March 2026)
  // This is what PerformanceService writes. Payroll reads this.
  // ─────────────────────────────────────────────────────────────
  Future<void> _seedMonthlyDeductions() async {
    final deductions = [
      // Ahmed — 2 missed tasks → 2 × 5% × 80,000 = 8,000 deduction
      {
        'employeeId':       'test_emp_001',
        'month':            3,
        'year':             2026,
        'totalTasks':       4,
        'completedTasks':   2,
        'missedTasks':      2,
        'weekendTasks':     0,
        'deductionAmount':  8000.0,   // 2 × 5% × 80,000
        'bonusAmount':      0.0,      // below bonus threshold
        'quarterlyScore':   50.0,     // 2/4 completed = 50%
        'calculatedAt':     Timestamp.fromDate(DateTime(2026, 3, 31)),
        'rulesSnapshot': {
          'missDeductionPct':    5,
          'completionBonusPct':  8,
          'deductionFrequency':  'monthly',
          'bonusThreshold':      80,
        },
      },

      // Sana — 0 missed, all 4 completed → no deduction, bonus applies
      // bonus = 8% × 120,000 = 9,600
      {
        'employeeId':       'test_emp_002',
        'month':            3,
        'year':             2026,
        'totalTasks':       4,
        'completedTasks':   4,
        'missedTasks':      0,
        'weekendTasks':     0,
        'deductionAmount':  0.0,
        'bonusAmount':      9600.0,   // 8% × 120,000
        'quarterlyScore':   100.0,
        'calculatedAt':     Timestamp.fromDate(DateTime(2026, 3, 31)),
        'rulesSnapshot': {
          'missDeductionPct':    5,
          'completionBonusPct':  8,
          'deductionFrequency':  'monthly',
          'bonusThreshold':      80,
        },
      },

      // Bilal — 1 missed → 1 × 5% × 60,000 = 3,000 deduction
      {
        'employeeId':       'test_emp_003',
        'month':            3,
        'year':             2026,
        'totalTasks':       4,
        'completedTasks':   3,
        'missedTasks':      1,
        'weekendTasks':     0,
        'deductionAmount':  3000.0,   // 1 × 5% × 60,000
        'bonusAmount':      0.0,
        'quarterlyScore':   75.0,
        'calculatedAt':     Timestamp.fromDate(DateTime(2026, 3, 31)),
        'rulesSnapshot': {
          'missDeductionPct':    5,
          'completionBonusPct':  8,
          'deductionFrequency':  'monthly',
          'bonusThreshold':      80,
        },
      },
    ];

    for (final d in deductions) {
      // Use employeeId_month_year as doc ID so it's easy to find/overwrite
      final docId =
          '${d['employeeId']}_${d['month']}_${d['year']}';
      await _db
          .collection('monthly_deductions')
          .doc(docId)
          .set(d, SetOptions(merge: true));
      print(
          '  📊 Seeded deduction: ${d['employeeId']} — '
              'missed: ${d['missedTasks']}, '
              'deduction: PKR ${d['deductionAmount']}, '
              'bonus: PKR ${d['bonusAmount']}');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ALSO SEED PAYROLL CONFIG  (allowances for each employee)
  // Optional — if no config exists, payroll uses salary only.
  // ─────────────────────────────────────────────────────────────
  Future<void> seedPayrollConfigs() async {
    final configs = [
      {
        'employeeId':          'test_emp_001',
        'employeeName':        'Ahmed Raza',
        'allowances': [
          {'name': 'House Rent', 'amount': 10000.0, 'type': 'fixed'},
          {'name': 'Transport',  'amount': 3000.0,  'type': 'fixed'},
        ],
        'loanDeductionPerMonth': 5000.0,
        'updatedBy':           'hr_001',
        'updatedAt':           Timestamp.fromDate(DateTime(2026, 3, 1)),
      },
      {
        'employeeId':          'test_emp_002',
        'employeeName':        'Sana Malik',
        'allowances': [
          {'name': 'House Rent', 'amount': 15000.0, 'type': 'fixed'},
          {'name': 'Medical',    'amount': 5.0,     'type': 'percentOfBasic'},
        ],
        'loanDeductionPerMonth': 0.0,
        'updatedBy':           'hr_001',
        'updatedAt':           Timestamp.fromDate(DateTime(2026, 3, 1)),
      },
      {
        'employeeId':          'test_emp_003',
        'employeeName':        'Bilal Khan',
        'allowances': [
          {'name': 'Transport', 'amount': 2000.0, 'type': 'fixed'},
        ],
        'loanDeductionPerMonth': 2000.0,
        'updatedBy':           'hr_001',
        'updatedAt':           Timestamp.fromDate(DateTime(2026, 3, 1)),
      },
    ];

    for (final c in configs) {
      final id = c['employeeId'] as String;
      await _db
          .collection('payroll_config')
          .doc(id)
          .set(c, SetOptions(merge: true));
      print('  ⚙️  Seeded config: $id');
    }

    print('✅ Payroll configs seeded.');
  }

  // ─────────────────────────────────────────────────────────────
  // CLEAR ALL TEST DATA
  // ─────────────────────────────────────────────────────────────
  Future<void> clearAll() async {
    print('🧹 Clearing payroll test data...');

    final empIds = ['test_emp_001', 'test_emp_002', 'test_emp_003'];

    for (final id in empIds) {
      // Delete users
      await _db.collection('users').doc(id).delete();

      // Delete monthly_deductions
      await _db
          .collection('monthly_deductions')
          .doc('${id}_3_2026')
          .delete();

      // Delete payroll_config
      await _db.collection('payroll_config').doc(id).delete();

      // Delete any generated payslips
      final payslips = await _db
          .collection('payslips')
          .where('employeeId', isEqualTo: id)
          .get();
      for (final doc in payslips.docs) {
        await doc.reference.delete();
      }
    }

    print('✅ Test data cleared.');
  }
}