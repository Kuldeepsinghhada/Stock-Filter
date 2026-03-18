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
    final Map<String, dynamic> data = <String, dynamic>{};
    data['ltp'] = ltp;
    data['chg'] = chg;
    data['perchg'] = perchg;
    return data;
  }
}