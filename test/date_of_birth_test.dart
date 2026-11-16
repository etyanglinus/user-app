import 'package:flutter_test/flutter_test.dart';
import 'package:fasta_deliveries/features/profile/domain/models/update_user_model.dart';
import 'package:fasta_deliveries/features/profile/domain/models/userinfo_model.dart';
import 'package:fasta_deliveries/features/profile/widgets/date_of_birth_field_widget.dart';

void main() {
  test('profile reads the date of birth and whether it is locked', () {
    final set = UserInfoModel.fromJson({'date_of_birth': '1994-08-20', 'date_of_birth_locked': true});
    expect(set.dateOfBirth, '1994-08-20');
    expect(set.dateOfBirthLocked, isTrue);
    final unset = UserInfoModel.fromJson({'date_of_birth': null});
    expect(unset.dateOfBirthLocked, isFalse);
  });

  test('the update sends the date only when there is one', () {
    expect(UpdateUserModel(name: 'A', dateOfBirth: '1994-08-20').toJson()['date_of_birth'], '1994-08-20');
    expect(UpdateUserModel(name: 'A').toJson().containsKey('date_of_birth'), isFalse);
  });

  test('display format', () {
    expect(DateOfBirthFieldWidget.display('1994-08-20'), '20 Aug 1994');
    expect(DateOfBirthFieldWidget.display(null), '');
  });
}
