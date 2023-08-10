import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:shopping_list_app/data/categories.dart';
import 'package:shopping_list_app/model/grocery_item.dart';
import 'package:shopping_list_app/screen/new_item_screen.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() {
    return _ShoppingListScreenState();
  }
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<GroceryItem> _groceryItems = [];
  var _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void onDismissed(GroceryItem groceryItem) async {
    final groceryIndex = _groceryItems.indexOf(groceryItem);
    setState(() {
      _groceryItems.remove(groceryItem);
    });

    final url = Uri.https(
      'flutter-prep-1b3c7-default-rtdb.firebaseio.com',
      'shopping-list/${groceryItem.id}.json',
    );

    final response = await http.delete(url);
    if (response.statusCode >= 400) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error: Item cannot be deleted',
            textAlign: TextAlign.center,
          ),
        ),
      );
      setState(() {
        _groceryItems.insert(groceryIndex, groceryItem);
      });
      return;
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Grocery Item Removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final url = Uri.https(
              'flutter-prep-1b3c7-default-rtdb.firebaseio.com',
              'shopping-list.json',
            );
            final response = await http.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(
                {
                  'name': groceryItem.name,
                  'quantity': groceryItem.quantity,
                  'category': groceryItem.category.name,
                },
              ),
            );
            final resData = json.decode(response.body);
            final newGroceryItem = GroceryItem(
              id: resData['name'],
              name: groceryItem.name,
              quantity: groceryItem.quantity,
              category: groceryItem.category,
            );

            setState(() {
              _groceryItems.insert(groceryIndex, newGroceryItem);
            });
          },
        ),
      ),
    );
  }

  void _loadItems() async {
    final url = Uri.https(
      'flutter-prep-1b3c7-default-rtdb.firebaseio.com',
      'shopping-list.json',
    );
    try{
      final response = await http.get(url);
      if(response.body == 'null'){
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final Map<String, dynamic> listData = json.decode(response.body);
      final List<GroceryItem> loadedItems = [];
      for (var item in listData.entries) {
        final categoryResult = categories.entries
            .firstWhere((element) => element.value.name == item.value['category'])
            .value;
        loadedItems.add(GroceryItem(
          id: item.key,
          name: item.value['name'],
          quantity: item.value['quantity'],
          category: categoryResult,
        ));
      }
      setState(() {
        _groceryItems = loadedItems;
        _isLoading = false;
      });
    } catch(error){
      setState(() {
          _error = 'Something Went Wrong! Please try again later.';
        });
    }
  }

  void _addItem() async {
    final newItem = await Navigator.of(context).push<GroceryItem>(
      MaterialPageRoute(
        builder: (ctx) => const NewItemScreen(),
      ),
    );
    setState(() {
      _groceryItems.add(newItem!);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget mainContent;
    if (_groceryItems.isNotEmpty) {
      mainContent = ListView.builder(
        itemCount: _groceryItems.length,
        itemBuilder: (ctx, index) => Dismissible(
          background: Container(
            color: Colors.red,
          ),
          key: ValueKey(_groceryItems[index].id),
          onDismissed: (direction) {
            onDismissed(_groceryItems[index]);
          },
          child: ListTile(
            title: Text(_groceryItems[index].name),
            leading: Container(
              width: 24,
              height: 24,
              color: _groceryItems[index].category.color,
            ),
            trailing: Text(_groceryItems[index].quantity.toString()),
          ),
        ),
      );
    } else if (_isLoading) {
      mainContent = const Center(
        child: CircularProgressIndicator(),
      );
    } else {
      mainContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'You have no Items',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(
              height: 20,
            ),
            Text(
              'Try Adding some!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            )
          ],
        ),
      );
    }
    if (_error != null) {
      mainContent = Center(
        child: Text(_error!),
      );
    }
    return Scaffold(
      appBar: AppBar(
        actions: [IconButton(onPressed: _addItem, icon: const Icon(Icons.add))],
        title: const Text('Your Groceries'),
      ),
      body: mainContent,
    );
  }
}
