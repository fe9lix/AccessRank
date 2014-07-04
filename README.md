AccessRank
==========

### About AccessRank

*AccessRank* is a Swift implementation of the [AccessRank algorithm by Fitchett and Cockburn](http://www.cosc.canterbury.ac.nz/andrew.cockburn/papers/AccessRank-camera.pdf) (full reference below) for iOS and Mac OS apps. The algorithm predicts which list items users might select or visit next by taking multiple sources of input into account. For instance, you could use *AccessRank* to generate a list of predictions for:
- which documents a user is most likely to open next.
- which commands in an auto-complete menu might be triggered next.
- which fonts in a font-chooser widget might be selected next.
- basically everthing in a user interface where reuse or revisitation of things is involved...

To improve on other common methods such as recency-based and frequency-based predictions, *AccessRank* adds Markov weights, time weighting, and other parameters for calculating a final score for each item, while the algorithm tries to maximize both prediction accurracy and list stability. Prediction accurracy is important since top items are easier and faster to access than items in bottom sections; list stability is important since automatic reordering of items can impede usability when users try to reselect an item based on an already learned location. You can configure the algorithm depending on whether you prefer more prediction accuracy or more list stability.

Once *AccessRank* has calculated predictions, you can use the resulting list to enhance your user interface in various ways. For example, you could display the most likely next items in an additional list as suggestions, or you could visually highlight relevant objects to give users cues where they might want to go next.

Here's the full reference for the [paper describing the formulas](http://www.cosc.canterbury.ac.nz/andrew.cockburn/papers/AccessRank-camera.pdf):

> Stephen Fitchett and Andy Cockburn. 2012. AccessRank: predicting what users will do next. In Proceedings of the SIGCHI Conference on Human Factors in Computing Systems (CHI '12). ACM, New York, NY, USA, 2239-2242.

### Installation

Just copy the folder `src/AccessRank` into your project. 

### Demo Project

The demo project shows a simple usage example: It contains a table view with country names and a text view with predictions. When you select a country name, the item is added to *AccessRank*, and the list of predictions for which item you might select next is updated.  
*Note*: The example doesn't use auto-layout due to some obscure bugs in Xcode 6 beta 2...

### Usage

Due to the Swift language currently lacking access modifiers, basically everything in AccessRank.swift is *public*. The properties and methods which are supposed to be used by clients are documented here.

#### Initializing

*AccessRank* is initialized with an enum value for the list stability that should be used for predictions. The default list stability is `.ListStability.Medium`. Other possible values are `.ListStability.Low` and `.ListStability.High`. *Low* stability means that prediction accurracy should be maximized while items are allowed to be reordered more than with other values. *High* stability means that the ordering of items should remain as stable as possible so that users can better learn item locations over time. The appropriate value to use here depends on your application domain. *Medium* stability is the default value and should be used if you are insecure which one to choose.  
(Also see the three unit tests on list stability in `AccessRankTests.swift` to get an idea on how this value affects predictions.)

```swift
let accessRank = AccessRank(listStability: AccessRank.ListStability.Medium)
```

#### Configuration

The only feature you can currently configure is turning *time weighting* on and off. The *time weighting* component of *AccessRank* takes the time of day and weekday into account. Put simply, items are given more weight when they are revisited in roughly the same time slot as previously. Since the calculation might currently be somewhat inefficient in its current form (although I haven't measured it), you can turn this feature off. You should turn it off if you need to work with large lists *and* if you are experiencing performance problems, or if you don't need time weighting in your application domain.

```swift
accessRank.useTimeWeighting = false
```

#### Adding Items

Adding items is as simple as calling the `mostRecentItem` property setter with an item id. You should set this property whenever a user selects an item in the list. The setter is implemented as an `optional` in Swift so that you can set it to `nil` when the user deselects an item.

```swift
accessRank.mostRecentItem = "A"
```

#### Removing Items

If your list is dynamic and items might be removed in repsonse to user interaction, you can remove previously added items by calling `removeItems` and passing the method an array of ids to be removed.

```swift
accessRank.removeItems(["A", "B"])
```

#### Predictions

The `predictions` property getter returns the current predictions as an array containing all your item ids (the ones you previously set using `mostRecentItem`) in sorted order. The first item in the array is the most likely next item. To display the predicated items somewhere in the user interface, these ids can then be matched to the item ids of your own list data structure. 

```swift
println("predictions: \(accessRank.predictions)")
```

#### Delegate Methods

The delegate method `accessRankDidUpdatePredictions(accessRank: AccessRank)` is called whenever the predictions are updated. Predictions are updated when you set `mostRecentItem`, or when you call `removeItems`.

```swift
accessRank.delegate = self

func accessRankDidUpdatePredictions(accessRank: AccessRank) {
    println("predictions: \(accessRank.predictions)")
}
```

#### Persistence

If you want to persist the current *AccessRank* data in your application beyond a single session, you can use the `toDictionary` method to get a snapshot of the data structure as dictionary for storage. The simplest solution is to store this dictionary in the user defaults (see the example app). You could also convert it to JSON and store it on a server, or in Core Data etc. 

Once you have stored the data, you can restore *AccessRank* by setting the dictionary as second parameter in the initializer:

```swift
let dataToPersist = accessRank.toDictionary()
        
let restoredAccessRank = AccessRank(
    listStability: AccessRank.ListStability.Medium,
    data: dataToPersist)
```

### Unit Tests

Although there's no exhaustive test coverage, a couple of unit tests in `AccessRankTests.swift` should at least make sure that the basics work. If you change the implementation of `AccessRank.swift`, make sure that all tests still pass or, even better, add new tests ;).
