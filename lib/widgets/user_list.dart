import 'package:flutter/material.dart';
import 'package:flutter_dart_fullstack/api/api_client.dart';

class UserList extends StatefulWidget {
  List<dynamic> users;
  final BuildContext context;
  
  UserList({Key? key, required this.users, required BuildContext this.context}) : super(key: key);

  @override
  State<UserList> createState() => _UserListState();
}

class _UserListState extends State<UserList> {
  final ApiClient client = ApiClient();

      Future<void> _deleteUser(int userid) async {
      print("DELETING.....");
    try {
      final response = await client.deleteUser(userid);
      
      if (response['success']) {
          ScaffoldMessenger.of(widget.context).showSnackBar(
            const SnackBar(content: Text('User deleted!'))
          );
          final usersResponse = await client.getUsers();
          setState(() {
            widget.users = usersResponse['users'];
          });
      }
    } catch (e) {
      print(e);
      if(mounted){
        ScaffoldMessenger.of(widget.context).showSnackBar(
          SnackBar(content: Text('Failed to delete user: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.users.length,
        separatorBuilder: (context, index) => Divider(),
        itemBuilder: (context, index) {
          final user = widget.users[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text('${user['id']}'),
            ),
            title: Text(user['name']),
            subtitle: Text(user['email']),
            trailing: MaterialButton(
              child: const Icon(Icons.delete, color: Colors.red,),
              onPressed: () async =>  {

                await _deleteUser(user['id'])
                
                },
            ),
          );
        },
      ),
    );
  }
}
