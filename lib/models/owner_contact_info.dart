class OwnerContactInfo {
  const OwnerContactInfo({
    this.storeId = '',
    this.siteUrl = '',
    this.email = '',
    this.phoneNumber = '',
    this.address = '',
    this.facebook = '',
    this.instagram = '',
    this.xAccount = '',
    this.businessHours = '',
  });

  final String storeId;
  final String siteUrl;
  final String email;
  final String phoneNumber;
  final String address;
  final String facebook;
  final String instagram;
  final String xAccount;
  final String businessHours;

  static const empty = OwnerContactInfo();

  factory OwnerContactInfo.fromMap(Map<String, dynamic> data) {
    return OwnerContactInfo(
      siteUrl: _stringValue(data['siteUrl']),
      email: _stringValue(data['email']),
      phoneNumber: _stringValue(data['phoneNumber']),
      address: _stringValue(data['address']),
      facebook: _stringValue(data['facebook']),
      instagram: _stringValue(data['instagram']),
      xAccount: _stringValue(data['xAccount']),
      businessHours: _stringValue(data['businessHours']),
      storeId: _stringValue(data['storeId']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'siteUrl': siteUrl,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'facebook': facebook,
      'instagram': instagram,
      'xAccount': xAccount,
      'businessHours': businessHours,
    };
  }

  static String _stringValue(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      return value.trim();
    }
    return value.toString();
  }
}
