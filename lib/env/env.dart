enum Environment { dev, staging, prod }

class AppEnv {
  static const Environment currentEnv = Environment.dev;

  static String get host {
    switch (currentEnv) {
      case Environment.dev:
        return "https://api.zalomi.sls.salonsyncs.com";
      case Environment.staging:
        return "https://api.zalomi.sls.salonsyncs.com";
      case Environment.prod:
        return "https://api.zalomi.sls.salonsyncs.com";
    }
  }
}
//784820
