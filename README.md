AccessRank
==========

### AccessRank

*AccessRank* is a Swift implementation of the [AccessRank algorithm by Fitchett and Cockburn](http://www.cosc.canterbury.ac.nz/andrew.cockburn/papers/AccessRank-camera.pdf) (full reference below) for iOS and Mac OS apps. The algorithm predicts which items in a list users might select, view, or visit next by taking multiple sources of input into account. In a document management application, for instance, you could use *AccessRank* to generate a list of predictions which documents the user is most likely to open next; in font chooser or color picker widget which fonts or colors might be selected next, and so on.

To improve on other common methods such as recency-based and frequency-based predictions, *AccessRank* adds Markov weights, time weighting, and other parameters for calculating a final score for each item. You can configure the algorithm depending on whether you prefer more prediction accuracy or list stability (i.e., minimizing the re-ordering of items).

Here's the full reference for the [paper describing the formulas.](http://www.cosc.canterbury.ac.nz/andrew.cockburn/papers/AccessRank-camera.pdf):

> Stephen Fitchett and Andy Cockburn. 2012. AccessRank: predicting what users will do next. In Proceedings of the SIGCHI Conference on Human Factors in Computing Systems (CHI '12). ACM, New York, NY, USA, 2239-2242.

### Installation

Just copy the folder `src/AccessRank` into your project. 

The demo project shows a simple usage example.

### Usage

```swift
var test = 1
```