import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'features/auth/session_repository.dart';
import 'features/home/app_shell.dart';

class DemoSessionRepository extends SessionRepository {
  DemoSessionRepository() : super();

  @override
  Future<bool> restore() async => true;

  @override
  Future<String?> accessToken() async => 'demo-token';

  @override
  Future<String?> householdId() async => 'household-1';

  @override
  Future<List<HouseholdCollectionItem>> recipes() async => [
        HouseholdCollectionItem({
          'id': 'recipe-1',
          'title': 'Tuscan Garlic Herb Pasta',
          'readiness': 'READY',
          'originalServings': '4',
          'yieldWording': '4 generous bowls',
          'tags': ['Dinner', 'Italian', 'Quick 25m'],
          'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        }),
        HouseholdCollectionItem({
          'id': 'recipe-2',
          'title': 'Crispy Glazed Salmon Bowls',
          'readiness': 'READY',
          'originalServings': '2',
          'yieldWording': '2 balanced bowls',
          'tags': ['Seafood', 'High-Protein', 'Fresh'],
          'createdAt': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
        }),
        HouseholdCollectionItem({
          'id': 'recipe-3',
          'title': 'Shakshuka with Feta & Fresh Cilantro',
          'readiness': 'NEEDS_REVIEW',
          'originalServings': '3',
          'yieldWording': '3 skillet servings',
          'tags': ['Brunch', 'Vegetarian', 'One-Pan'],
          'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        }),
        HouseholdCollectionItem({
          'id': 'recipe-4',
          'title': 'Slow-Simmered San Marzano Tomato Soup',
          'readiness': 'READY',
          'originalServings': '6',
          'yieldWording': '6 warming bowls',
          'tags': ['Soup', 'Comfort Food', 'Meal Prep'],
          'createdAt': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
        }),
      ];

  @override
  Future<RecipeReview> recipeReview(String recipeId) async => RecipeReview(
        id: recipeId,
        title: 'Tuscan Garlic Herb Pasta',
        readiness: 'READY',
        revision: '2',
        originalServings: '4',
        yieldWording: '4 bowls',
        completeness: const RecipeCompleteness(extracted: 7, manual: 0, missing: 0),
        evidence: const [],
        sourceUrl: 'https://cooking.nytimes.com/recipes/tuscan-pasta',
        ingredients: [
          RecipeReviewIngredient(
            name: 'Rigatoni pasta',
            quantityMin: '500',
            quantityMax: '500',
            originalUnit: 'g',
            preparationNote: 'bronze-die cut preferred',
            classification: 'REQUIRED',
            includeInShopping: true,
            originalText: '500g rigatoni pasta',
          ),
          RecipeReviewIngredient(
            name: 'Fresh garlic',
            quantityMin: '6',
            quantityMax: '6',
            originalUnit: 'cloves',
            preparationNote: 'thinly sliced',
            classification: 'REQUIRED',
            includeInShopping: true,
            originalText: '6 cloves garlic, thinly sliced',
          ),
          RecipeReviewIngredient(
            name: 'Heavy cream',
            quantityMin: '200',
            quantityMax: '200',
            originalUnit: 'ml',
            preparationNote: 'room temperature',
            classification: 'REQUIRED',
            includeInShopping: true,
            originalText: '200ml heavy cream',
          ),
          RecipeReviewIngredient(
            name: 'Parmigiano Reggiano',
            quantityMin: '60',
            quantityMax: '60',
            originalUnit: 'g',
            preparationNote: 'freshly microplaned',
            classification: 'REQUIRED',
            includeInShopping: true,
            originalText: '60g Parmigiano Reggiano, finely grated',
          ),
          RecipeReviewIngredient(
            name: 'Sun-dried tomatoes',
            quantityMin: '100',
            quantityMax: '100',
            originalUnit: 'g',
            preparationNote: 'oil-packed, drained & julienned',
            classification: 'REQUIRED',
            includeInShopping: true,
            originalText: '100g oil-packed sun-dried tomatoes',
          ),
          RecipeReviewIngredient(
            name: 'Fresh baby spinach',
            quantityMin: '150',
            quantityMax: '150',
            originalUnit: 'g',
            preparationNote: 'washed and trimmed',
            classification: 'OPTIONAL',
            includeInShopping: true,
            originalText: '150g baby spinach leaves',
          ),
          RecipeReviewIngredient(
            name: 'Extra virgin olive oil',
            quantityMin: '3',
            quantityMax: '3',
            originalUnit: 'tbsp',
            preparationNote: 'first cold press',
            classification: 'PANTRY_STAPLE',
            includeInShopping: false,
            originalText: '3 tablespoons extra virgin olive oil',
          ),
        ],
        instructions: [
          'Bring a large pot of salted water to a rolling boil and cook rigatoni until 1 minute shy of al dente.',
          'Gently sauté sliced garlic and sun-dried tomatoes in olive oil over medium-low heat until fragrant.',
          'Pour in the heavy cream, simmer for 3 minutes until slightly thickened, and whisk in Parmigiano Reggiano.',
          'Fold in fresh baby spinach until wilted, then toss the pasta into the silky sauce with pasta water.',
          'Plate in warm diner bowls, garnish with torn fresh basil and cracked black pepper.',
        ],
      );

  @override
  Future<List<HouseholdCollectionItem>> cookingInstances() async {
    final now = DateTime.now();
    final todayIso = DateTime(now.year, now.month, now.day, 19, 0).toIso8601String();
    final tomorrowIso = DateTime(now.year, now.month, now.day + 1, 19, 30).toIso8601String();
    return [
      HouseholdCollectionItem({
        'id': 'cook-1',
        'recipeId': 'recipe-1',
        'recipeTitle': 'Tuscan Garlic Herb Pasta',
        'targetServings': '4',
        'cookingDate': todayIso,
        'status': 'SCHEDULED',
        'shoppingTripId': 'trip-1',
        'assignedCookName': 'Adam',
      }),
      HouseholdCollectionItem({
        'id': 'cook-2',
        'recipeId': 'recipe-2',
        'recipeTitle': 'Crispy Glazed Salmon Bowls',
        'targetServings': '2',
        'cookingDate': tomorrowIso,
        'status': 'SCHEDULED',
        'shoppingTripId': 'trip-1',
        'assignedCookName': 'Sarah',
      }),
    ];
  }

  @override
  Future<List<HouseholdCollectionItem>> shoppingTrips() async {
    final now = DateTime.now();
    final todayTrip = DateTime(now.year, now.month, now.day, 17, 30).toIso8601String();
    final nextTrip = DateTime(now.year, now.month, now.day + 4, 10, 0).toIso8601String();
    return [
      HouseholdCollectionItem({
        'id': 'trip-1',
        'scheduledFor': todayTrip,
        'status': 'CONFIRMED',
        'label': 'Trader Joe’s Run (Dinner Prep)',
        'itemCount': 6,
      }),
      HouseholdCollectionItem({
        'id': 'trip-2',
        'scheduledFor': nextTrip,
        'status': 'PROPOSED',
        'label': 'Weekend Market & Bakery',
        'itemCount': 3,
      }),
    ];
  }

  @override
  Future<HouseholdCollectionItem> shoppingTripDetail(String tripId) async {
    final now = DateTime.now();
    final todayTrip = DateTime(now.year, now.month, now.day, 17, 30).toIso8601String();
    return HouseholdCollectionItem({
      'id': 'trip-1',
      'scheduledFor': todayTrip,
      'status': 'CONFIRMED',
      'label': 'Trader Joe’s Run (Dinner Prep)',
      'items': [
        {
          'id': 'item-1',
          'displayName': 'Rigatoni pasta',
          'status': 'BOUGHT',
          'demand': [
            {'dimension': 'MASS', 'unit': 'g', 'min': 500.0, 'max': 500.0}
          ],
          'estimate': {
            'amount': 500.0,
            'unit': 'g',
            'buyCount': 1,
            'buySize': 500.0,
            'crossesDimension': false,
            'remainderApplied': false,
          },
        },
        {
          'id': 'item-2',
          'displayName': 'Heavy cream',
          'status': 'NEED_TO_BUY',
          'demand': [
            {'dimension': 'VOLUME', 'unit': 'ml', 'min': 200.0, 'max': 200.0}
          ],
          'estimate': {
            'amount': 250.0,
            'unit': 'ml',
            'buyCount': 1,
            'buySize': 250.0,
            'crossesDimension': false,
            'remainderApplied': false,
          },
        },
        {
          'id': 'item-3',
          'displayName': 'Fresh garlic',
          'status': 'NEED_TO_BUY',
          'demand': [
            {'dimension': 'COUNT', 'unit': 'heads', 'min': 1.0, 'max': 1.0}
          ],
          'estimate': {
            'amount': 1.0,
            'unit': 'head',
            'buyCount': 1,
            'buySize': 1.0,
            'crossesDimension': false,
            'remainderApplied': false,
          },
        },
        {
          'id': 'item-4',
          'displayName': 'Atlantic salmon fillets',
          'status': 'NEED_TO_BUY',
          'demand': [
            {'dimension': 'MASS', 'unit': 'g', 'min': 400.0, 'max': 450.0}
          ],
          'estimate': {
            'amount': 450.0,
            'unit': 'g',
            'buyCount': 2,
            'buySize': 225.0,
            'crossesDimension': false,
            'remainderApplied': false,
          },
        },
        {
          'id': 'item-5',
          'displayName': 'Baby spinach',
          'status': 'NEED_TO_BUY',
          'demand': [
            {'dimension': 'MASS', 'unit': 'g', 'min': 150.0, 'max': 150.0}
          ],
          'estimate': {
            'amount': 200.0,
            'unit': 'g',
            'buyCount': 1,
            'buySize': 200.0,
            'crossesDimension': false,
            'remainderApplied': false,
          },
        },
        {
          'id': 'item-6',
          'displayName': 'Parmigiano Reggiano wedge',
          'status': 'ALREADY_HAVE',
          'demand': [
            {'dimension': 'MASS', 'unit': 'g', 'min': 60.0, 'max': 60.0}
          ],
          'estimate': null,
        },
      ],
    });
  }

  @override
  Future<List<HouseholdCollectionItem>> archive() async => [
        HouseholdCollectionItem({
          'id': 'arch-1',
          'recipeTitle': 'Homemade Sourdough Margherita Pizza',
          'cookedAt': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
          'servings': 4,
          'notes': 'Crust had exceptional blistering and rise. 72hr cold ferment worked wonders.',
          'rating': 5,
        }),
        HouseholdCollectionItem({
          'id': 'arch-2',
          'recipeTitle': 'Japanese Golden Curry with Root Vegetables',
          'cookedAt': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(),
          'servings': 6,
          'notes': 'Hearty and balanced. Saved 2 portions in freezer archive.',
          'rating': 5,
        }),
      ];

  @override
  Future<List<HouseholdCollectionItem>> notifications() async => [
        HouseholdCollectionItem({
          'id': 'notif-1',
          'title': 'Shopping trip confirmed',
          'body': 'Trader Joe’s Run scheduled for 17:30 today with 6 items.',
          'createdAt': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
          'read': false,
        }),
        HouseholdCollectionItem({
          'id': 'notif-2',
          'title': 'Cook assignment: Dinner tonight',
          'body': 'Adam assigned to cook Tuscan Garlic Herb Pasta.',
          'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          'read': true,
        }),
      ];
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final demoRepo = DemoSessionRepository();

  runApp(
    ProviderScope(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(demoRepo),
        sessionRestoreProvider.overrideWith((ref) => Future.value(true)),
        authenticatedProvider.overrideWith((ref) => true),
      ],
      child: const _DemoApp(),
    ),
  );
}

class _DemoApp extends ConsumerWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'PantryPal',
      debugShowCheckedModeBanner: false,
      theme: PantryPalTheme.light(),
      darkTheme: PantryPalTheme.dark(),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}
