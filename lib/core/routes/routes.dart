enum Routes {
  qr("/"),
  timer("/timer"),
  test("/test");

  const Routes(this.path);

  final String path;
}