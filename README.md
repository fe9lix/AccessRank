AccessRank
==========

### About AccessRank

*AccessRank* is a Swift implementation of the [AccessRank algorithm by Fitchett and Cockburn](http://www.cosc.canterbury.ac.nz/andrew.cockburn/papers/AccessRank-camera.pdf) (full reference below) for iOS and Mac OS apps. The algorithm predicts which list items users might select or visit next by taking multiple sources of input into account. For instance, you could use *AccessRank* to generate a list of predictions for:
- which documents a user is most likely to open next.
- which commands in an auto-complete menu might be triggered next.
- which fonts in a font-chooser widget might be selected next.
- basically every part in a user interface where reuse or revisitation of things is involved...

To improve on other common methods such as recency-based and frequency-based predictions, *AccessRank* adds Markov weights, time weighting, and other parameters for calculating a final score for each item, while the algorithm tries to maximize both prediction accuracy and list stability. Prediction accuracy is important since top items are easier and faster to access than items in bottom sections; list stability is important since automatic reordering of items can impede usability when users try to reselect an item based on an already learned location. You can configure the algorithm depending on whether you prefer more prediction accuracy or more list stability.

Once *AccessRank* has calculated predictions, you can use the resulting list to enhance your user interface in various ways. For example, you could display the most likely next items in an additional list as suggestions, or you could visually highlight relevant objects to give users cues where they might want to go next.

Here's the full reference for the [paper](http://www.cosc.canterbury.ac.nz/andrew.cockburn/papers/AccessRank-camera.pdf):

> Stephen Fitchett and Andy Cockburn. 2012. AccessRank: predicting what users will do next. In Proceedings of the SIGCHI Conference on Human Factors in Computing Systems (CHI '12). ACM, New York, NY, USA, 2239-2242.

Thanks to Stephen Fitchett for answering my questions and giving feedback!

### Installation

Just copy the folder `src/AccessRank` into your project. The latest version requires Swift 3 and Xcode 8. 

### Demo Project

The demo project shows a simple usage example: It contains a table view with item names and a text view with predictions. When you select an item, it is added to *AccessRank*, and the list of predictions for which item you might select next is updated. When the app is moved to the background state, an *AccessRank* snapshot is saved to the user defaults (also see the section on persistence).

### Usage

Public methods and properties are documented in the following sections.

#### Initializing

*AccessRank* is initialized with an enum value for the list stability that should be used for predictions. The default list stability is `.medium`. Other possible values are `.low` and `.high`. *Low* stability means that prediction accuracy should be maximized while items are allowed to be reordered more than with other values. *High* stability means that the ordering of items should remain as stable as possible so that users can better learn item locations over time. The appropriate value to use here depends on your application domain. *Medium* stability is the default value and should be used if you are insecure which one to choose.
(Also see the three unit tests on list stability in `AccessRankTests.swift` to get an idea on how this value affects predictions.)  

The parameter `maxVisits` caps the prediction list at the specified number. Use a reasonable value to control the amount of performance needed each time `visitItem` (see below) is called. 

```swift
let accessRank = AccessRank(listStability: .medium, maxVisits: 1000)
```

#### Configuration

The only feature you can currently configure is turning *time weighting* on and off. The *time weighting* component of *AccessRank* takes the time of day and weekday into account. Put simply, items are given more weight when they are revisited in roughly the same time slot as previously. If you don't need time weighting in your application domain, you should turn this feature off to increase performance.

```swift
accessRank.useTimeWeighting = false
```

#### Visiting Items

Visiting items is as simple as calling the method `visitItem` with an item id. You should call this method whenever a user selects an item in the list (i.e., visits or uses the item). The parameter is an `optional` so that you can pass `nil` when the user deselects an item.

```swift
accessRank.visitItem("A")
```

#### Most Recent Item

Calling the property getter `mostRecentItem` returns the most recently visited item id as `optional`.

```swift
println("mostRecentItem: \(accessRank.mostRecentItem)")
```

#### Removing Items

If your list is dynamic and items might be removed in response to user interaction, you can remove previously added items by calling `removeItems` and passing the method an array of ids to be removed.

```swift
accessRank.removeItems(["A", "B"])
```

#### Predictions

The `predictions` property getter returns the current predictions as array containing all your item ids (the ones you previously set using `mostRecentItem`) in sorted order. The first item in the array is the most likely next item. To display the predicted items somewhere in the user interface, these ids can then be matched to the item ids of your own list data structure. 

```swift
println("predictions: \(accessRank.predictions)")
```

#### Delegate Methods

The delegate method `accessRankDidUpdatePredictions(_ accessRank: AccessRank)` is called whenever the predictions are updated. Predictions are updated when you set `mostRecentItem`, or when you call `removeItems`.

```swift
accessRank.delegate = self

func accessRankDidUpdatePredictions(accessRank: AccessRank) {
    println("predictions: \(accessRank.predictions)")
}
```

#### Persistence

AccessRank implements Swift's Codable protocol. To persist a snapshot in user defaults, you could do:

```swift
// Encode
let encodedAccessRank = try? JSONEncoder().encode(accessRank)
UserDefaults.standard.set(encodedAccessRank, forKey: "accessRank")

// Decode
if let jsonData = UserDefaults.standard.data(forKey: "accessRank") {
    let decodedAccessRank = try? JSONDecoder().decode(AccessRank.self, from: jsonData)
}
```

### Unit Tests

Although there's no exhaustive test coverage, a couple of unit tests in `AccessRankTests.swift` should at least make sure that the basics work. If you change the implementation of `AccessRank.swift`, make sure that all tests still pass or, even better, add new tests ;).
