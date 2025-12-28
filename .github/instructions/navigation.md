## Generated Routes

A `PageRouteInfo` object will be generated for every declared **AutoRoute**. These objects hold strongly-typed page arguments which are extracted from the page's default constructor. Think of them as string path segments on steroids.

```dart
class BookListRoute extends PageRouteInfo {
  const BookListRoute({
    List<PageRouteInfo>? children,
  }) : super(name, initialChildren: children);

  static const String name = 'BookListRoute';
  static const PageInfo page = PageInfo(name,builder: (...));
}
```

## Navigating Between Screens

`AutoRouter` offers the same known push, pop and friends methods to manipulate the pages stack using both the generated `PageRouteInfo` objects and paths.

```dart
// get the scoped router by calling
AutoRouter.of(context);
// or using the extension
context.router;
// adds a new entry to the pages stack
router.push(const BooksListRoute());
// or by using paths
router.pushPath('/books');
// removes last entry in stack and pushes provided route
// if last entry == provided route page will just be updated
router.replace(const BooksListRoute());
// or by using paths
router.replacePath('/books');
// pops until provided route, if it already exists in stack
// else adds it to the stack (good for web Apps).
router.navigate(const BooksListRoute());
// or by using paths
router.navigatePath('/books');
// on Web it calls window.history.back();
// on Native it navigates you back
// to the previous location
router.back();
// adds a list of routes to the pages stack at once
router.pushAll([
  BooksListRoute(),
  BookDetailsRoute(id: 1),
]);
// This is like providing a completely new stack as it rebuilds the stack
// with the list of passed routes
// entries might just update if already exist
router.replaceAll([
  LoginRoute(),
]);

// pops the top page even if it's the last entry in stack
context.router.pop()
// pops the most top page of the most top router even if it's the last entry in stack
context.router.popTop();

// pops the last page unless blocked or stack has only 1 entry
context.router.maybePop();
// pops the most top page of the most top router unless blocked
// or stack has only 1 entry
context.router.maybePopTop();
// keeps popping routes until predicate is satisfied
context.router.popUntil((route) => route.settings.name == 'HomeRoute');
// a simplified version of the above line
context.router.popUntilRouteWithName('HomeRoute');
// keeps popping routes until route with provided path is found
context.router.popUntilRouteWithPath('/some-path');
// pops all routes down to the root
context.router.popUntilRoot();
// removes the top most page in stack even if it's the last
// remove != pop, it doesn't respect WillPopScopes it just
// removes the entry.
context.router.removeLast();
// removes any route in stack that satisfies the predicate
// this works exactly like removing items from a regular List
// <PageRouteInfo>[...].removeWhere((r)=>)
context.router.removeWhere((route) => route.name == 'SomeRoute');
// you can also use the common helper methods from context extension to navigate
context.pushRoute(const BooksListRoute());
context.replaceRoute(const BooksListRoute());
context.navigateTo(const BooksListRoute());
context.navigateToPath('/books');
context.back();
context.maybePop();
context.pop();
```

## Passing Arguments

That's the fun part! **AutoRoute** automatically detects and handles your page arguments for you, the generated route object will deliver all the arguments your page needs including path/query params.

e.g. The following page widget will take an argument of type `Book`.

```dart
@RoutePage()
class BookDetailsPage extends StatelessWidget {
  const BookDetailsPage({required this.book});

  final Book book;
  ...
```

**Note:** Default values are respected. Required fields are also respected and handled properly.

The generated `BookDetailsRoute` will deliver the same arguments to its corresponding page.

```dart
router.push(BookDetailsRoute(book: book));
```

**Note:** All arguments are generated as named parameters regardless of their original type.

## Returning Results

You can return results by either using the pop completer or by passing a callback function as an argument the same way you'd pass an object.

#### 1. Using the `pop` completer

```dart
var result = await router.push(LoginRoute());
```

then inside of your `LoginPage`, pop with results

```dart
router.maybePop(true);
```

Specifying the type of the result is optional, but it's recommended to avoid runtime errors.

```dart
var result = await router.push<bool>(LoginRoute());
```

and of course we pop with the same type

```dart
router.maybePop<bool>(true);
```

#### 2. Passing a callback function as an argument.

We only have to add a callback function as a parameter to our page constructor like follows:

```dart
@RoutePage()
class BookDetailsPage extends StatelessWidget {
  const BookDetailsPage({this.book, required this.onRateBook});

  final Book book;
  final void Function(int) onRateBook;
  ...
```

The generated `BookDetailsRoute` will deliver the same arguments to its corresponding page.

```dart
context.pushRoute(
  BookDetailsRoute(
    book: book,
    onRateBook: (rating) {
      // handle result
    },
  ),
);
```

If you're finishing with results, make sure you call the callback function as you pop the page

```dart
onRateBook(RESULT);
context.maybePop();
```
## Tab Navigation

If you're working with flutter mobile, you're most likely to implement tabs navigation, that's why `auto_route` makes tabs navigation as easy and straightforward as possible.

In the previous example we used an `AutoRouter` widget to render nested child routes, `AutoRouter` is just a shortcut for `AutoStackRouter`. `StackRouters` manage a stack of pages inside of them, where the active/visible page is always the one on top and you'd need to pop it to see the page beneath it.

Now we can try to implement our tabs using an `AutoRouter` (StackRouter) by pushing or replacing a nested route every time the tab changes and that might work, but our tabs state will be lost, not to mention the transition between tabs issue, luckily auto_route comes equipped with an `AutoTabsRouter`, which is especially made to handle tab navigation.

`AutoTabsRouter` lets you switch between different routes while preserving offstage-routes state, tab routes are lazily loaded by default (can be disabled) and it finally allows to create whatever transition animation you want.

Let's change the previous example to use tab navigation.

Notice that we're not going to change anything in our routes declaration map, we still have a dashboard page that has three nested children: users, posts and settings.

```dart
class DashboardPage extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      // list of your tab routes
      // routes used here must be declared as children
      // routes of /dashboard
      routes: const [
        UsersRoute(),
        PostsRoute(),
        SettingsRoute(),
      ],
      transitionBuilder: (context,child,animation) => FadeTransition(
            opacity: animation,
            // the passed child is technically our animated selected-tab page
            child: child,
          ),
      builder: (context, child) {
        // obtain the scoped TabsRouter controller using context
        final tabsRouter = AutoTabsRouter.of(context);
        // Here we're building our Scaffold inside of AutoTabsRouter
        // to access the tabsRouter controller provided in this context
        //
        // alternatively, you could use a global key
        return Scaffold(
          body: child,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: tabsRouter.activeIndex,
            onTap: (index) {
              // here we switch between tabs
              tabsRouter.setActiveIndex(index);
            },
            items: [
              BottomNavigationBarItem(label: 'Users', ...),
              BottomNavigationBarItem(label: 'Posts', ...),
              BottomNavigationBarItem(label: 'Settings', ...),
            ],
          ),
        );
      },
    );
  }
}
```

If you think the above setup is a bit messy you could use the shipped-in `AutoTabsScaffold` that makes things much cleaner.

```dart
class DashboardPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AutoTabsScaffold(
      routes: const [
        UsersRoute(),
        PostsRoute(),
        SettingsRoute(),
      ],
      bottomNavigationBuilder: (_, tabsRouter) {
        return BottomNavigationBar(
          currentIndex: tabsRouter.activeIndex,
          onTap: tabsRouter.setActiveIndex,
          items: const [
            BottomNavigationBarItem(label: 'Users', ...),
            BottomNavigationBarItem(label: 'Posts', ...),
            BottomNavigationBarItem(label: 'Settings', ...),
          ],
        );
      },
    );
  }
}
```
