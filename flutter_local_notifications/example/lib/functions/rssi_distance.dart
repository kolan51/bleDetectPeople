import 'dart:math';

class RssiDistance {
  double? R = 0.125; //  Process Noise
  double? Q = 0.5; //  Measurement Noise
  double? A = 1; //  State Vector
  double? B = 0; //  Control Vector
  double? C = 1; //  Measurement Vector

  double? x; //  Filtered Measurement Value (No Noise)
  double? cov; //  Covariance

  double calculateFilter(double rssi) => applyFilter(rssi, 0);

  double applyFilter(double measurement, double u) {
    double predX; //  Predicted Measurement Value
    double K; //  Kalman Gain
    double predCov; //  Predicted Covariance
    if (x == null) {
      x = (1 / C!) * measurement;
      cov = (1 / C!) * Q! * (1 / C!);
    } else {
      predX = predictValue(u);
      predCov = getUncertainty();
      K = predCov * C! * (1 / ((C! * predCov * C!) + Q!));
      x = predX + K * (measurement - (C! * predX));
      cov = predCov - (K * C! * predCov);
    }
    return x!;
  }

  double predictValue(double control) => (A! * x!) + (B! * control);

  double getUncertainty() => ((A! * cov!) * A!) + R!;

  double calcDistbyRSSI(int kalmanRssi, {int measurePower = -59}) {
    final int iRssi = kalmanRssi.abs();
    final int iMeasurePower = measurePower.abs();
    final double power = (iRssi - iMeasurePower) / (10 * 2.0);

    if (pow(10.0, power) * 3.2808 < 1.0) {
      return pow(10.0, power) * 3.2808;
    } else if (pow(10.0, power) * 3.2808 > 1.0 &&
        pow(10.0, power) * 3.2808 < 10.0) {
      return pow(10.0, power) * 3.2808;
    } else {
      return pow(10.0, power) * 3.2808;
    }
  }
}
