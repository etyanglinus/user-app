class UpdateUserModel {
  String? name;
  String? email;
  String? phone;
  String? otp;
  String? buttonType;
  String? sessionInfo;
  String? verificationOn;
  String? verificationMedium;
  String? dateOfBirth;

  UpdateUserModel({
    this.name,
    this.email,
    this.phone,
    this.otp,
    this.buttonType,
    this.sessionInfo,
    this.verificationOn,
    this.verificationMedium,
    this.dateOfBirth,
  });

  UpdateUserModel.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    email = json['email'];
    phone = json['phone'];
    otp = json['otp'];
    buttonType = json['button_type'];
    sessionInfo = json['session_info'];
    verificationOn = json['verification_on'];
    verificationMedium = json['verification_medium'];
    dateOfBirth = json['date_of_birth'];
  }

  Map<String, String> toJson() {
    final Map<String, String> data = <String, String>{};
    data['name'] = name ?? '';
    data['email'] = email ?? '';
    data['phone'] = phone ?? '';
    data['otp'] = otp ?? '';
    data['button_type'] = buttonType ?? '';
    if (dateOfBirth != null && dateOfBirth!.isNotEmpty) {
      data['date_of_birth'] = dateOfBirth!;
    }
    if (sessionInfo != null) {
      data['session_info'] = sessionInfo ?? '';
    }
    if (verificationOn != null) {
      data['verification_on'] = verificationOn ?? '';
    }
    if (verificationMedium != null) {
      data['verification_medium'] = verificationMedium ?? '';
    }
    return data;
  }
}
