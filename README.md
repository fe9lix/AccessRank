AccessRank
==========

### AccessRank

*AccessRank* is a Swift implementation of the [AccessRank algorithm by Fitchett and Cockburn](http://www.cosc.canterbury.ac.nz/andrew.cockburn/papers/AccessRank-camera.pdf) (full reference below) for iOS and Mac OS apps. The algorithm predicts which items in a list users might select, view, or visit next by taking multiple sources of input into account. For instance, you could use *AccessRank* to generate a list of predictions for:
- which documents the user is most likely to open next
- which commands in a auto-complete menu might be triggered next
- which fonts in a font chooser widget might be selected next
- basically everthing where reuse or revisitation of things is involved...

To improve on other common methods such as recency-based and frequency-based predictions, *AccessRank* adds Markov weights, time weighting, and other parameters for calculating a final score for each item while the algorithm tries to maximize both prediction accurracy and list stability. (Prediction accurracy is important since top items are easier and faster to access than items in the bottom section; list stability is important since the automatic re-ordering of items can impede usability when users try to reselect an item based on an already learned location.) You can configure the algorithm depending on whether you prefer more prediction accuracy or more list stability.

Here's the full reference for the [paper describing the formulas.](http://www.cosc.canterbury.ac.nz/andrew.cockburn/papers/AccessRank-camera.pdf):

> Stephen Fitchett and Andy Cockburn. 2012. AccessRank: predicting what users will do next. In Proceedings of the SIGCHI Conference on Human Factors in Computing Systems (CHI '12). ACM, New York, NY, USA, 2239-2242.

### Installation

Just copy the folder `src/AccessRank` into your project. 

The demo project shows a simple usage example.

### Usage

```swift
var test = 1
```

REMOVE ITEMS!!!

### Usage

- Example doesn't use auto-layout due to some obscure bugs in Xcode beta 2