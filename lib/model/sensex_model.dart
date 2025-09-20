class SensexModel {
  String? ltp;
  String? chg;
  String? perchg;

  SensexModel({this.ltp, this.chg, this.perchg});

  SensexModel.fromJson(Map<String, dynamic> json) {
    ltp = json['ltp'];
    chg = json['chg'];
    perchg = json['perchg'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['ltp'] = this.ltp;
    data['chg'] = this.chg;
    data['perchg'] = this.perchg;
    return data;
  }
}