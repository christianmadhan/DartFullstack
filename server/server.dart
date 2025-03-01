// ========================
// server/server.dart
// ========================
import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

class AppServer {
  // Server instance
  HttpServer? _server;
  final int port;
  final String host;
  final String projectRoot = Directory.current.path;
  late Database db;
  
  // API router
  final _apiRouter = shelf_router.Router();
  
  AppServer({this.port = 8080, this.host = 'localhost'}) {
    // Initialize API routes
    final String dbpath = path.join(projectRoot, 'server', 'database');
    db = sqlite3.open('$dbpath/ddragon2.db');
  
  // Create the Users table if it doesn't exist
    db.execute('''
      CREATE TABLE IF NOT EXISTS Users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE
      )
    ''');
    _setupApiRoutes();
  }
  
  void _setupApiRoutes() {
    // Define API endpoints
    _apiRouter.get('/api/users', _handleGetUsers);
    _apiRouter.post('/api/users', _handleCreateUser);
    _apiRouter.post('/api/delete/<id>', _handleDeleteUser);
    
    // Add more routes as needed
  }
  
  
  Future<shelf.Response> _handleGetUsers(shelf.Request request) async {
    // Mock data - in a real app, you would fetch from a database
    final users = [];
    final ResultSet resultSet = db.select('SELECT * FROM Users');
    for (final Row row in resultSet) {
      users.add({'id': row['id'], 'name': row['name'], 'email': row['email']},);
    }
    
    return shelf.Response.ok(
      jsonEncode({'users': users}),
      headers: {'content-type': 'application/json'}
    );
  }

    Future<shelf.Response> _handleDeleteUser(shelf.Request request, String user) async {
      print("trying to delete user with id: $user");

    try {
      final stmt = db.prepare(
      'DELETE FROM Users WHERE id = ?'
      );
      // Bind parameters and execute
      stmt.execute([user]);
      // In a real app, you would save to a database
      return shelf.Response.ok(
        jsonEncode({
          'success': true,
          'message': 'User deleted'
        }),
        headers: {'content-type': 'application/json'}
      );
    } catch (e) {
      print("exception delete ---------");
      print(e.toString());
      print("exception delete ---------");
      return shelf.Response.badRequest(
        body: jsonEncode({'error': 'Invalid JSON data'}),
        headers: {'content-type': 'application/json'}
      );
    }
  }
  
  Future<shelf.Response> _handleCreateUser(shelf.Request request) async {
    final String body = await request.readAsString();
    
    try {
      final Map<String, dynamic> userData = jsonDecode(body);
      final stmt = db.prepare(
      'INSERT INTO Users (name, email) VALUES (?, ?)'
      );
      // Bind parameters and execute
      stmt.execute([userData['name'], userData['email']]);
      final int userId = db.lastInsertRowId;
      print(userData);
      print("New Id: $userId");
      // In a real app, you would save to a database
      return shelf.Response.ok(
        jsonEncode({
          'success': true,
          'message': 'User created',
          'user': {'id': userId, ...userData}
        }),
        headers: {'content-type': 'application/json'}
      );
    } catch (e) {
      print("exception---------");
      print(e.toString());
      print("exception---------");
      return shelf.Response.badRequest(
        body: jsonEncode({'error': 'Invalid JSON data'}),
        headers: {'content-type': 'application/json'}
      );
    }
  }
  
  // CORS middleware
  shelf.Handler _addCorsHeaders(shelf.Handler innerHandler) {
    return (request) async {
      final response = await innerHandler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, X-Auth-Token',
        ...response.headers,
      });
    };
  }
  
  // Start the server
  Future<void> start() async {
    // Determine the directory where Flutter web build is located
    final String projectRoot = Directory.current.path;
    final String webBuildPath = path.join(projectRoot, 'build', 'web');
    
    // Create a static file handler for the Flutter web build
    final staticHandler = createStaticHandler(
      webBuildPath,
      defaultDocument: 'index.html'
    );
    
    // Create a cascade that tries API routes first, then falls back to static files
    final cascade = shelf.Cascade()
        .add(_apiRouter)
        .add(staticHandler);
    
    // Apply middleware
    final handler = shelf.Pipeline()
        //.addMiddleware(shelf.logRequests())
        .addMiddleware(_addCorsHeaders)
        .addHandler(cascade.handler);
    
    // Start server
    _server = await shelf_io.serve(handler, host, port);
    
    print('Server running on http://$host:$port');
    print('API available at http://$host:$port/api/');
    print('Flutter web app served from $webBuildPath');
  }
  
  // Stop the server
  Future<void> stop() async {
    await _server?.close();
    print('Server stopped');
  }
}

void main() async {
  final server = AppServer(port: 8080);
  await server.start();
  
  // Handle shutdown gracefully
  ProcessSignal.sigint.watch().listen((_) async {
    await server.stop();
    exit(0);
  });
}