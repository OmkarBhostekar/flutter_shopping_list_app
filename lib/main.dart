import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_shopping_list_app/controllers/auth_controller.dart';
import 'package:flutter_shopping_list_app/controllers/item_list_controller.dart';
import 'package:flutter_shopping_list_app/model/item_model.dart';
import 'package:flutter_shopping_list_app/repositories/custom_exceptions.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shopping List App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final authControllerState = useProvider(authControllerProvider.state);
    final itemListFilter = useProvider(itemListFilterProvider);
    final isObtainedFilter = itemListFilter.state == ItemListFilter.obtained;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        centerTitle: true,
        leading: authControllerState != null
            ? IconButton(
                onPressed: () => context.read(authControllerProvider).signOut(),
                icon: Icon(Icons.logout))
            : null,
        actions: [
          IconButton(
              onPressed: () => itemListFilter.state = isObtainedFilter
                  ? ItemListFilter.all
                  : ItemListFilter.obtained,
              icon: Icon(isObtainedFilter
                  ? Icons.check_circle
                  : Icons.check_circle_outline))
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AddItemDialog.show(context, Item.empty()),
        child: Icon(Icons.add),
      ),
      body: ProviderListener(
        provider: itemListExceptionProvider,
        onChange: (BuildContext context,
            StateController<CustomException?> customException) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(customException.state!.message!)));
        },
        child: const ItemList(),
      ),
    );
  }
}

final currentItem = ScopedProvider<Item>((_) => throw UnimplementedError());

class ItemList extends HookWidget {
  const ItemList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final itemListState = useProvider(itemListControllerProvider.state);
    final filteredItemList = useProvider(filteredItemListProvider);
    return itemListState.when(
        data: (items) => items.isEmpty
            ? const Center(
                child: Text(
                  'Tap + to add an item',
                  style: TextStyle(fontSize: 20.0),
                ),
              )
            : ListView.builder(
                itemCount: filteredItemList.length,
                itemBuilder: (BuildContext context, int index) {
                  final item = filteredItemList[index];
                  return ProviderScope(
                      overrides: [currentItem.overrideWithValue(item)],
                      child: ItemTile());
                }),
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, _) => ItemListError(
            message: err is CustomException
                ? err.message!
                : 'Something went wrong!'));
  }
}

class ItemTile extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final item = useProvider(currentItem);
    return ListTile(
      key: ValueKey(item.id),
      title: Text(item.name),
      trailing: Checkbox(
        value: item.obtained,
        onChanged: (val) => context
            .read(itemListControllerProvider)
            .upateItem(updatedItem: item.copyWith(obtained: !item.obtained)),
      ),
      onTap: () => AddItemDialog.show(context, item),
      onLongPress: () =>
          context.read(itemListControllerProvider).deleteItem(itemId: item.id!),
    );
  }
}

class ItemListError extends StatelessWidget {
  final String message;

  const ItemListError({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(message,
            style: TextStyle(
              fontSize: 20.0,
            )),
        const SizedBox(height: 20.0),
        ElevatedButton(
            onPressed: () =>
                context.read(itemListControllerProvider).retrieveItems(),
            child: const Text('Retry'))
      ],
    );
  }
}

class AddItemDialog extends HookWidget {
  static void show(BuildContext context, Item item) {
    showDialog(
        context: context, builder: (context) => AddItemDialog(item: item));
  }

  final Item item;
  const AddItemDialog({Key? key, required this.item}) : super(key: key);

  bool get isUpdating => item.id != null;

  @override
  Widget build(BuildContext context) {
    final textController = useTextEditingController(text: item.name);
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Item name'),
            ),
            const SizedBox(
              height: 12.0,
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      primary: isUpdating
                          ? Colors.orange
                          : Theme.of(context).primaryColor),
                  onPressed: () {
                    isUpdating
                        ? context.read(itemListControllerProvider).upateItem(
                            updatedItem: item.copyWith(
                                name: textController.text.trim(),
                                obtained: item.obtained))
                        : context
                            .read(itemListControllerProvider)
                            .addItem(name: textController.text.trim());
                    Navigator.of(context).pop();
                  },
                  child: Text(isUpdating ? 'Update' : 'Add')),
            )
          ],
        ),
      ),
    );
  }
}
