# Live Activity / Live Notification — Complete Implementation Guide

> **Purpose**: This document is a full AI-readable skill guide for implementing real-time, persistent,
> glanceable notifications (a.k.a. "Live Activities") across iOS and Android, with Flutter as the
> primary framework. Based on Grab's engineering approach and official platform APIs.

---

## Table of Contents

1. [Concept Overview](#1-concept-overview)
2. [Architecture — How It Works (Grab Model)](#2-architecture--how-it-works-grab-model)
3. [iOS Live Activities (ActivityKit)](#3-ios-live-activities-activitykit)
4. [Android Live Notifications](#4-android-live-notifications)
5. [Flutter Implementation](#5-flutter-implementation)
6. [Push Notification Integration](#6-push-notification-integration)
7. [UI Design Patterns](#7-ui-design-patterns)
8. [Best Practices & Constraints](#8-best-practices--constraints)
9. [Reference Links](#9-reference-links)

---

## 1. Concept Overview

### What Is a "Live Activity"?

A **Live Activity** is a persistent, real-time notification that updates in-place without sending
repeated push notifications. Instead of bombarding the user with 5+ separate "order received",
"kitchen preparing", "driver on the way" notifications, a single Live Activity widget updates
its content dynamically.

### Key Characteristics

| Property | Description |
|---|---|
| **Persistent** | Stays pinned to lock screen / notification drawer — not dismissible until task completes |
| **Real-time** | Content updates without user interaction (via push or local update) |
| **Glanceable** | Compact UI showing essential info (progress bar, ETA, status text) |
| **User-initiated** | Only shown for actions the user triggered (place order, start ride, etc.) |
| **Finite lifecycle** | Has distinct start → progress → end states |

### Platform Names

| Platform | Feature Name | Min Version |
|---|---|---|
| iOS | **Live Activities** (ActivityKit) | iOS 16.1+ |
| iOS | **Dynamic Island** | iPhone 14 Pro+ / iOS 16.1+ |
| Android (native) | **Live Updates** (ProgressStyle) | Android 16+ (API 36) |
| Android (pre-16) | **Custom Notification** (RemoteViews) | Android 7+ (API 24) |

---

## 2. Architecture — How It Works (Grab Model)

Grab's architecture uses 4 components communicating via tokens and push notifications.

### System Components

```
┌─────────────┐  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐
│  Pax App     │  │  API / OM   │  │ Grab Device  │  │  Hedwig     │
│ (User App)   │  │ (Backend)   │  │  (Device     │  │ (Push       │
│              │  │             │  │   Service)   │  │  Service)   │
└──────┬───────┘  └──────┬──────┘  └──────┬───────┘  └──────┬──────┘
       │                 │                │                  │
```

### Flow — Solution 1 (Selected by Grab)

**Phase 1: Create Order (Registration)**
```
Pax App                    API/OM              Grab Device         Hedwig
  │                          │                     │                 │
  │── Create Order ─────────>│                     │                 │
  │<── OrderID ──────────────│                     │                 │
  │                          │                     │                 │
  │── LiveActivityToken ─────┼────────────────────>│                 │
  │   + OrderID              │                     │                 │
  │                          │                     │                 │
  │   (Token = placeholder   │                     │                 │
  │    ID for Android,       │                     │                 │
  │    real APNS token       │                     │                 │
  │    for iOS)              │                     │                 │
```

**Phase 2: Order Status Update (Notification)**
```
Pax App                    API/OM              Grab Device         Hedwig
  │                          │                     │                 │
  │   Order Status Update ──>│                     │                 │
  │                          │── send Push ────────┼────────────────>│
  │                          │                     │                 │
  │                          │                     │<─ get Token ────│
  │                          │                     │   by OrderID    │
  │                          │                     │── Token ───────>│
  │                          │                     │                 │
  │<── Push Notification ────┼─────────────────────┼─────────────────│
  │    (liveActivityPushType)│                     │                 │
  │                          │                     │                 │
  │── Update Live Activity UI│                     │                 │
```

### Flow — Solution 2 (Alternative)

Same as Solution 1 but with a **decision diamond** at Hedwig:
- Check if LiveActivityToken is a real APNS token (iOS/Grab-style) → YES: proceed normally
- If NO (Android placeholder) → skip APNS, use alternative delivery (FCM/direct)

**Grab chose Solution 1** because it maintains platform consistency and ensures
notifications only reach Live Activity-capable devices.

### Key Concept: LiveActivityToken

| Platform | Token Type | Description |
|---|---|---|
| iOS | Real APNS Push Token | Generated by ActivityKit when Live Activity starts |
| Android | Placeholder/Dummy Token | App-generated unique ID (e.g., OrderID) used as notification identifier |

The token is registered with the backend (Grab Device service) so the push service
(Hedwig) can look it up by OrderID and send targeted updates.

---

## 3. iOS Live Activities (ActivityKit)

### 3.1 Core Framework: ActivityKit

ActivityKit is Apple's framework for managing Live Activities. It handles:
- Creating/starting a Live Activity
- Updating content in real-time
- Ending/dismissing the activity
- Generating push tokens for remote updates

### 3.2 Data Model

```swift
// ActivityAttributes — defines static + dynamic data
struct OrderActivityAttributes: ActivityAttributes {
    // STATIC data (immutable for lifetime of activity)
    var orderNumber: String
    var restaurantName: String
    var restaurantLogo: String

    // DYNAMIC data (changes with each update)
    struct ContentState: Codable, Hashable {
        var status: OrderStatus          // .received, .preparing, .onTheWay, .delivered
        var driverName: String?
        var estimatedDelivery: Date
        var progressPercent: Double      // 0.0 - 1.0
        var statusMessage: String        // "Kitchen's preparing your order"
    }
}

enum OrderStatus: String, Codable {
    case received, preparing, onTheWay, arrived, delivered
}
```

### 3.3 Lifecycle Methods

```swift
// START a Live Activity
let attributes = OrderActivityAttributes(
    orderNumber: "12345",
    restaurantName: "Ayam Guling Enakko"
)
let initialState = OrderActivityAttributes.ContentState(
    status: .received,
    estimatedDelivery: Date().addingTimeInterval(30 * 60),
    progressPercent: 0.1,
    statusMessage: "Order received"
)
let content = ActivityContent(state: initialState, staleDate: nil)

let activity = try Activity.request(
    attributes: attributes,
    content: content,
    pushType: .token    // Enable push updates
)

// GET push token (send to your server)
for await tokenData in activity.pushTokenUpdates {
    let token = tokenData.map { String(format: "%02x", $0) }.joined()
    // Send token + orderID to backend
    await sendTokenToServer(token: token, orderID: "12345")
}

// UPDATE locally
let updatedState = OrderActivityAttributes.ContentState(
    status: .preparing,
    estimatedDelivery: Date().addingTimeInterval(25 * 60),
    progressPercent: 0.35,
    statusMessage: "Kitchen's preparing your order"
)
await activity.update(ActivityContent(state: updatedState, staleDate: nil))

// END the activity
let finalState = OrderActivityAttributes.ContentState(
    status: .delivered,
    progressPercent: 1.0,
    statusMessage: "Delivered! Enjoy your meal!"
)
await activity.end(
    ActivityContent(state: finalState, staleDate: nil),
    dismissalPolicy: .after(.now + 60 * 5)  // Dismiss after 5 min
)
```

### 3.4 APNS Push Payload for Live Activities

**Required HTTP Headers:**
```
apns-push-type: liveactivity
apns-topic: <bundle-id>.push-type.liveactivity
apns-priority: 10
authorization: bearer <jwt-token>
```

**Start Event (Push-to-Start):**
```json
{
  "aps": {
    "timestamp": 1709000000,
    "event": "start",
    "content-state": {
      "status": "received",
      "driverName": null,
      "estimatedDelivery": 1709001800,
      "progressPercent": 0.1,
      "statusMessage": "Order received"
    },
    "attributes-type": "OrderActivityAttributes",
    "attributes": {
      "orderNumber": "12345",
      "restaurantName": "Ayam Guling Enakko"
    },
    "alert": {
      "title": "Order Received",
      "body": "We'll let you know when it's in the kitchen",
      "sound": "default"
    }
  }
}
```

**Update Event:**
```json
{
  "aps": {
    "timestamp": 1709000300,
    "event": "update",
    "content-state": {
      "status": "preparing",
      "driverName": null,
      "estimatedDelivery": 1709001500,
      "progressPercent": 0.35,
      "statusMessage": "Kitchen's preparing your order"
    },
    "alert": {
      "title": "Preparing Your Order",
      "body": "We'll let you know when it's out for delivery",
      "sound": "default"
    }
  }
}
```

**End Event:**
```json
{
  "aps": {
    "timestamp": 1709001800,
    "event": "end",
    "content-state": {
      "status": "delivered",
      "driverName": "Ahmad",
      "estimatedDelivery": 1709001800,
      "progressPercent": 1.0,
      "statusMessage": "Delivered! Enjoy your meal!"
    },
    "dismissal-date": 1709002100,
    "alert": {
      "title": "Order Delivered",
      "body": "Thanks for ordering with us. Enjoy!",
      "sound": "default"
    }
  }
}
```

### 3.5 Dynamic Island Regions

```
┌───────────────────────────────────────────┐
│ Compact View (pill shape)                 │
│  ┌──────────┐          ┌──────────┐       │
│  │ Leading   │          │ Trailing │       │
│  │ (icon)    │          │ (timer)  │       │
│  └──────────┘          └──────────┘       │
└───────────────────────────────────────────┘

┌───────────────────────────────────────────┐
│ Expanded View (long-press)                │
│  ┌──────────┐  ┌────────┐  ┌──────────┐  │
│  │ Leading   │  │ Center │  │ Trailing │  │
│  └──────────┘  └────────┘  └──────────┘  │
│  ┌──────────────────────────────────────┐ │
│  │ Bottom (full width)                  │ │
│  │ Progress bar, ETA, etc.              │ │
│  └──────────────────────────────────────┘ │
└───────────────────────────────────────────┘
```

### 3.6 Constraints (iOS)

| Constraint | Value |
|---|---|
| Max simultaneous activities | 2 per app |
| Max Lock Screen persistence | 8 hours (12h for some categories) |
| ContentState payload max size | 4 KB |
| Push token refresh | Automatic, observe `pushTokenUpdates` |
| Frequent updates plist key | `NSSupportsLiveActivitiesFrequentUpdates = YES` |

---

## 4. Android Live Notifications

Android has two approaches depending on API level:

### 4.1 Approach A: Android 16+ — ProgressStyle (Official Live Updates)

**This is the native, official equivalent of iOS Live Activities.**

**Permission Required:**
```xml
<uses-permission android:name="android.permission.POST_PROMOTED_NOTIFICATIONS" />
```

**Creating a Live Update:**
```kotlin
// Create notification channel
val channel = NotificationChannel(
    "live_updates",
    "Live Updates",
    NotificationManager.IMPORTANCE_HIGH  // NOT IMPORTANCE_MIN
).apply {
    description = "Real-time order tracking"
}
notificationManager.createNotificationChannel(channel)

// Build Live Update notification
val builder = NotificationCompat.Builder(context, "live_updates")
    .setSmallIcon(R.drawable.ic_notification)
    .setContentTitle("Order Received")
    .setContentText("We'll let you know when it's in the kitchen")
    .setOngoing(true)                          // Required: persistent
    .setRequestPromotedOngoing(true)           // Request promotion to Live Update
    .setProgress(100, 10, false)               // Progress bar
    .setShortCriticalText("ETA: 30 min")       // Status bar chip text
    .setCategory(NotificationCompat.CATEGORY_PROGRESS)
    .setPriority(NotificationCompat.PRIORITY_HIGH)

notificationManager.notify(NOTIFICATION_ID, builder.build())
```

**Updating:**
```kotlin
// Just rebuild and re-notify with same ID
val updated = NotificationCompat.Builder(context, "live_updates")
    .setSmallIcon(R.drawable.ic_notification)
    .setContentTitle("Kitchen's Preparing Your Order")
    .setContentText("We'll let you know when it's out for delivery")
    .setOngoing(true)
    .setRequestPromotedOngoing(true)
    .setProgress(100, 35, false)
    .setShortCriticalText("ETA: 25 min")

notificationManager.notify(NOTIFICATION_ID, updated.build())
```

**Ending:**
```kotlin
// Option 1: Cancel
notificationManager.cancel(NOTIFICATION_ID)

// Option 2: Show completion, then auto-dismiss
val completed = NotificationCompat.Builder(context, "live_updates")
    .setSmallIcon(R.drawable.ic_check)
    .setContentTitle("Order Delivered!")
    .setContentText("Thanks for ordering with us. Enjoy!")
    .setOngoing(false)          // No longer persistent
    .setAutoCancel(true)        // Dismiss on tap
    .setProgress(100, 100, false)

notificationManager.notify(NOTIFICATION_ID, completed.build())
```

**Status Bar Chip Rules:**
- Max width: 96dp
- Shows icon always, text optionally
- < 7 chars: show full text
- Text > 50% overflow: icon only

**Allowed vs Disallowed Use Cases:**
```
ALLOWED:                        DISALLOWED:
- Food delivery tracking        - Ads / promotions
- Ride-share tracking           - Chat messages
- Active navigation             - Upcoming calendar events
- Ongoing phone calls           - Package tracking (not active)
- Live sports (user-initiated)  - Ambient info / quick shortcuts
```

### 4.2 Approach B: Pre-Android 16 — Custom Notification with RemoteViews (Grab's Approach)

This is how Grab implemented Live Activity on Android before official support existed.
Use `RemoteViews` to create a custom notification layout.

**XML Layout** (`res/layout/notification_live_activity.xml`):
```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="vertical"
    android:padding="12dp">

    <!-- Row 1: App icon + Brand -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center_vertical">

        <ImageView
            android:id="@+id/iv_brand_logo"
            android:layout_width="24dp"
            android:layout_height="24dp"
            android:src="@drawable/ic_app_logo" />

        <TextView
            android:id="@+id/tv_brand_name"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginStart="8dp"
            android:text="Enakko"
            android:textSize="12sp"
            android:textColor="#888888" />
    </LinearLayout>

    <!-- Row 2: Status title -->
    <TextView
        android:id="@+id/tv_status_title"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:text="Order received"
        android:textSize="16sp"
        android:textStyle="bold"
        android:textColor="#000000" />

    <!-- Row 3: Status description -->
    <TextView
        android:id="@+id/tv_status_description"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="2dp"
        android:text="We'll let you know when it's in the kitchen"
        android:textSize="14sp"
        android:textColor="#666666" />

    <!-- Row 4: Progress bar + destination icon -->
    <RelativeLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="8dp">

        <ProgressBar
            android:id="@+id/progress_bar"
            style="@android:style/Widget.ProgressBar.Horizontal"
            android:layout_width="match_parent"
            android:layout_height="6dp"
            android:layout_centerVertical="true"
            android:layout_toStartOf="@+id/iv_destination"
            android:layout_marginEnd="8dp"
            android:max="100"
            android:progress="10"
            android:progressDrawable="@drawable/progress_gradient" />

        <ImageView
            android:id="@+id/iv_destination"
            android:layout_width="20dp"
            android:layout_height="20dp"
            android:layout_alignParentEnd="true"
            android:layout_centerVertical="true"
            android:src="@drawable/ic_location_pin" />
    </RelativeLayout>
</LinearLayout>
```

**Kotlin — Custom Notification with RemoteViews:**
```kotlin
class LiveActivityNotificationManager(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "live_activity_channel"
        const val NOTIFICATION_ID = 9001
    }

    private val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    init {
        createChannel()
    }

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Order Tracking",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Real-time order status updates"
            setShowBadge(false)
        }
        notificationManager.createNotificationChannel(channel)
    }

    fun showLiveActivity(
        brandName: String,
        statusTitle: String,
        statusDescription: String,
        progressPercent: Int
    ) {
        // Create RemoteViews for collapsed (48dp max height)
        val collapsedView = RemoteViews(context.packageName, R.layout.notification_live_activity_collapsed)
        collapsedView.setTextViewText(R.id.tv_status_title, statusTitle)
        collapsedView.setProgressBar(R.id.progress_bar, 100, progressPercent, false)

        // Create RemoteViews for expanded (252dp max height)
        val expandedView = RemoteViews(context.packageName, R.layout.notification_live_activity)
        expandedView.setTextViewText(R.id.tv_brand_name, brandName)
        expandedView.setTextViewText(R.id.tv_status_title, statusTitle)
        expandedView.setTextViewText(R.id.tv_status_description, statusDescription)
        expandedView.setProgressBar(R.id.progress_bar, 100, progressPercent, false)

        // Build notification
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomContentView(collapsedView)       // Collapsed layout
            .setCustomBigContentView(expandedView)     // Expanded layout
            .setOngoing(true)                          // Non-dismissible
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    fun updateLiveActivity(
        statusTitle: String,
        statusDescription: String,
        progressPercent: Int
    ) {
        // Re-call showLiveActivity — Android updates in-place with same NOTIFICATION_ID
        showLiveActivity("Enakko", statusTitle, statusDescription, progressPercent)
    }

    fun endLiveActivity() {
        notificationManager.cancel(NOTIFICATION_ID)
    }
}
```

**Constraints for Custom Notification (RemoteViews):**

| Constraint | Value |
|---|---|
| Collapsed height max | 48dp |
| Expanded height max | 252dp |
| No interactive widgets | Only TextView, ImageView, ProgressBar, Chronometer |
| No custom fonts | System fonts only |
| Update frequency | No hard limit, but avoid > 1/sec (battery drain) |

### 4.3 Grab's Interface Design Pattern

Grab abstracts the notification system behind clean interfaces:

```kotlin
// Interface for starting/updating/canceling Live Activities
interface LiveActivityIntegrationManager {
    fun startLiveActivity(vertical: Vertical, id: String): Completable
    fun updateLiveActivity(id: String, attributes: LiveActivityAttributes)
    fun cancelLiveActivity(id: String)
}

// Vertical = type of service (Food, Mart, Express, Transport)
enum class Vertical { FOOD, MART, EXPRESS, TRANSPORT }

// Attributes encapsulate ALL UI data
data class LiveActivityAttributes(
    val iconRes: Int,                     // App/brand icon
    val headerIcon: Int?,                 // Service-specific icon
    val contentTitle: String,             // "Kitchen's preparing your order"
    val contentText: String,              // "We'll let you know when..."
    val footerProgress: Int?,             // 0-100 progress
    val footerIcon: Int?,                 // Destination pin
    val pendingIntent: PendingIntent?     // Tap action → open app
)

// Low-level manager that talks to Android NotificationManager
interface LiveActivityManager {
    fun notify(id: Int, attributes: LiveActivityAttributes)
    fun cancel(id: Int)
}
```

---

## 5. Flutter Implementation

### 5.1 Package Options

| Package | iOS Support | Android Support | Notes |
|---|---|---|---|
| `live_activities` (istornz) | Full (ActivityKit) | Beta (RemoteViews) | Most popular, active development |
| `flutter_live_activities` (fluttercandies) | Full | Beta | Alternative option |
| Manual Platform Channels | Full control | Full control | More work, maximum flexibility |

### 5.2 Using `live_activities` Package

**pubspec.yaml:**
```yaml
dependencies:
  live_activities: ^2.0.0  # Check latest version
```

**iOS Setup (Required — Native Swift Code):**

1. **Xcode → File → New → Target → Widget Extension** (name: `LiveActivityWidget`)

2. **Add capabilities to Runner:**
   - Push Notifications
   - Background Modes → Remote notifications
   - App Groups (e.g., `group.com.enakko.absensi`)

3. **Add App Groups to Widget Extension** (same group ID)

4. **Info.plist (both Runner AND Widget Extension):**
   ```xml
   <key>NSSupportsLiveActivities</key>
   <true/>
   <key>NSSupportsLiveActivitiesFrequentUpdates</key>
   <true/>
   ```

5. **Create ActivityAttributes in Swift:**
   ```swift
   // LiveActivityWidget/LiveActivitiesAppAttributes.swift
   import ActivityKit

   struct LiveActivitiesAppAttributes: ActivityAttributes {
       // Static data — passed once at creation
       public struct ContentState: Codable, Hashable {
           // Dynamic data — updated via push or local update
           // All fields are passed as Map<String, dynamic> from Flutter
       }
   }
   ```

6. **Create Widget UI in SwiftUI:**
   ```swift
   // LiveActivityWidget/LiveActivityWidget.swift
   import WidgetKit
   import SwiftUI

   struct LiveActivityWidget: Widget {
       var body: some WidgetConfiguration {
           ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
               // Lock Screen UI
               LockScreenView(context: context)
           } dynamicIsland: { context in
               DynamicIsland {
                   // Expanded regions
                   DynamicIslandExpandedRegion(.leading) { /* ... */ }
                   DynamicIslandExpandedRegion(.trailing) { /* ... */ }
                   DynamicIslandExpandedRegion(.bottom) { /* ... */ }
               } compactLeading: {
                   // Compact leading
               } compactTrailing: {
                   // Compact trailing
               } minimal: {
                   // Minimal view
               }
           }
       }
   }
   ```

**Android Setup (Required — Native Kotlin Code):**

1. **`android/app/src/main/kotlin/.../MainActivity.kt`:**
   ```kotlin
   import dev.music.music.flutter_live_activities.LiveActivityManagerHolder

   class MainActivity : FlutterActivity() {
       override fun onCreate(savedInstanceState: Bundle?) {
           super.onCreate(savedInstanceState)
           LiveActivityManagerHolder.manager = CustomLiveActivityManager(this)
       }
   }
   ```

2. **Create `CustomLiveActivityManager.kt`:**
   ```kotlin
   class CustomLiveActivityManager(private val context: Context) : LiveActivityManager(context) {

       override suspend fun buildNotification(
           notification: Notification.Builder,
           event: String,  // "create", "update", "end"
           data: Map<String, Any>
       ): Notification {
           val remoteViews = RemoteViews(context.packageName, R.layout.live_activity)

           // Read data from Flutter
           val title = data["title"] as? String ?: ""
           val body = data["body"] as? String ?: ""
           val progress = (data["progress"] as? Number)?.toInt() ?: 0

           remoteViews.setTextViewText(R.id.tv_status_title, title)
           remoteViews.setTextViewText(R.id.tv_status_description, body)
           remoteViews.setProgressBar(R.id.progress_bar, 100, progress, false)

           return notification
               .setCustomContentView(remoteViews)
               .setOngoing(event != "end")
               .build()
       }
   }
   ```

3. **Create XML layout** (`android/app/src/main/res/layout/live_activity.xml`):
   See the XML example in Section 4.2 above.

**Flutter (Dart) — Usage:**
```dart
import 'package:live_activities/live_activities.dart';

final liveActivities = LiveActivities();

// Initialize (call once)
await liveActivities.init(appGroupId: 'group.com.enakko.absensi');

// CREATE a live activity
final activityId = await liveActivities.createActivity({
  'title': 'Order Received',
  'body': "We'll let you know when it's in the kitchen",
  'progress': 10,
  'status': 'received',
  'orderNumber': '12345',
  'restaurantName': 'Ayam Guling Enakko',
});

// UPDATE the live activity
await liveActivities.updateActivity(activityId, {
  'title': "Kitchen's Preparing Your Order",
  'body': "We'll let you know when it's out for delivery",
  'progress': 35,
  'status': 'preparing',
});

// END the live activity
await liveActivities.endActivity(activityId);

// LISTEN for push token (iOS)
liveActivities.activityUpdateStream.listen((event) {
  if (event is LiveActivityTokenUpdate) {
    // Send event.token to your backend
    sendTokenToBackend(token: event.token, orderID: '12345');
  }
});
```

### 5.3 Manual Platform Channel Approach (Full Control)

If you need maximum control, use MethodChannels to bridge Flutter ↔ Native:

**Flutter Side:**
```dart
class LiveActivityService {
  static const _channel = MethodChannel('com.enakko.absensi/live_activity');

  static Future<String?> startActivity({
    required String orderNumber,
    required String statusTitle,
    required String statusBody,
    required int progressPercent,
  }) async {
    return await _channel.invokeMethod<String>('startLiveActivity', {
      'orderNumber': orderNumber,
      'statusTitle': statusTitle,
      'statusBody': statusBody,
      'progressPercent': progressPercent,
    });
  }

  static Future<void> updateActivity({
    required String activityId,
    required String statusTitle,
    required String statusBody,
    required int progressPercent,
  }) async {
    await _channel.invokeMethod('updateLiveActivity', {
      'activityId': activityId,
      'statusTitle': statusTitle,
      'statusBody': statusBody,
      'progressPercent': progressPercent,
    });
  }

  static Future<void> endActivity(String activityId) async {
    await _channel.invokeMethod('endLiveActivity', {
      'activityId': activityId,
    });
  }
}
```

**Android (Kotlin) Side:**
```kotlin
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.enakko.absensi/live_activity"
    private lateinit var liveActivityManager: LiveActivityNotificationManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        liveActivityManager = LiveActivityNotificationManager(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLiveActivity" -> {
                        val title = call.argument<String>("statusTitle") ?: ""
                        val body = call.argument<String>("statusBody") ?: ""
                        val progress = call.argument<Int>("progressPercent") ?: 0
                        liveActivityManager.showLiveActivity("Enakko", title, body, progress)
                        result.success("activity_${System.currentTimeMillis()}")
                    }
                    "updateLiveActivity" -> {
                        val title = call.argument<String>("statusTitle") ?: ""
                        val body = call.argument<String>("statusBody") ?: ""
                        val progress = call.argument<Int>("progressPercent") ?: 0
                        liveActivityManager.updateLiveActivity(title, body, progress)
                        result.success(null)
                    }
                    "endLiveActivity" -> {
                        liveActivityManager.endLiveActivity()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
```

---

## 6. Push Notification Integration

### 6.1 Server-Side Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────┐
│ Your Backend │────>│ Push Service │────>│ APNS (iOS)      │
│ (Supabase /  │     │ (FCM /      │     │ FCM (Android)   │
│  Node.js)    │     │  OneSignal)  │     │                 │
└──────┬───────┘     └─────────────┘     └────────┬────────┘
       │                                          │
       │  Store: orderID → pushToken              │
       │  (LiveActivityToken for iOS,             │
       │   FCM token for Android)                 ▼
       │                                   ┌──────────────┐
       └──────────────────────────────────>│  User Device  │
                                           │  Live Activity │
                                           └──────────────┘
```

### 6.2 Token Registration Flow

```
1. User places order → App creates Live Activity
2. iOS: ActivityKit generates APNS push token
   Android: App generates FCM token (or uses existing one)
3. App sends token + orderID to backend
4. Backend stores mapping: { orderID: token, platform: "ios"|"android" }
5. On status change, backend looks up token by orderID
6. Backend sends push to APNS (iOS) or FCM (Android)
7. Device receives push → updates Live Activity UI
```

### 6.3 Supabase Edge Function Example (for push delivery)

```typescript
// supabase/functions/update-order-status/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  const { orderId, newStatus, statusMessage, progressPercent } = await req.json();

  // Look up push token from database
  const { data: tokenRow } = await supabase
    .from('order_push_tokens')
    .select('token, platform')
    .eq('order_id', orderId)
    .single();

  if (tokenRow.platform === 'ios') {
    // Send APNS Live Activity update
    await sendAPNS({
      token: tokenRow.token,
      payload: {
        aps: {
          timestamp: Math.floor(Date.now() / 1000),
          event: newStatus === 'delivered' ? 'end' : 'update',
          'content-state': {
            status: newStatus,
            progressPercent: progressPercent,
            statusMessage: statusMessage,
          },
          alert: {
            title: statusMessage,
            body: `Order #${orderId}`,
          },
        },
      },
    });
  } else {
    // Send FCM data message (Android handles it in notification code)
    await sendFCM({
      token: tokenRow.token,
      data: {
        type: 'live_activity_update',
        orderId: orderId,
        status: newStatus,
        statusMessage: statusMessage,
        progressPercent: String(progressPercent),
      },
    });
  }

  return new Response(JSON.stringify({ success: true }));
});
```

### 6.4 FCM Handling on Android (Flutter)

```dart
// In your Firebase messaging handler
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  if (message.data['type'] == 'live_activity_update') {
    LiveActivityService.updateActivity(
      activityId: currentActivityId,
      statusTitle: message.data['statusMessage'],
      statusBody: _getBodyForStatus(message.data['status']),
      progressPercent: int.parse(message.data['progressPercent']),
    );
  }
});
```

---

## 7. UI Design Patterns

### 7.1 GrabFood Notification Layout (Reference from Images)

The notification UI follows this 5-element pattern:

```
┌──────────────────────────────────────────────────┐
│ 1. [G] Grab · now                           [^]  │  ← App icon + name + timestamp
│                                                   │
│ 2. GrabFood / GrabMart                           │  ← Service brand label (green)
│                                                   │
│ 3. Kitchen's preparing your order                │  ← Status title (bold, large)
│                                                   │
│ 4. We'll let you know when it's out for delivery │  ← Status description (gray)
│                                                   │
│ 5. [============================------] [📍]     │  ← Progress bar + destination
│    ■■■■■■■■■■■■■■■■■■░░░░░░░░░░  [🚗] [📍]     │     icon + optional vehicle
└──────────────────────────────────────────────────┘
```

### 7.2 Status Progression States

```
State 1: Order Received
├── Title: "Order received"
├── Body: "We'll let you know when it's in the kitchen"
├── Progress: 10%
└── Icon: Restaurant pin

State 2: Kitchen Preparing
├── Title: "Kitchen's preparing your order"
├── Body: "We'll let you know when it's out for delivery"
├── Progress: 35%
└── Icon: Restaurant pin

State 3: Driver Picking Up
├── Title: "Driver is picking up your order"
├── Body: "Almost there!"
├── Progress: 55%
└── Icon: Car icon approaching

State 4: On the Way
├── Title: "Your order is on the way"
├── Body: "Arriving in ~10 minutes"
├── Progress: 75%
└── Icon: Car icon + destination pin

State 5: Driver Arrived
├── Title: "Driver arrived at 10:02 PM"  ← time in GREEN
├── Body: "Thanks for ordering with us. Enjoy!"
├── Progress: 100%
└── Icon: Car icon at destination pin
```

### 7.3 Color Scheme

| Element | Color |
|---|---|
| Brand label ("GrabFood") | `#00B14F` (Grab green) |
| Progress bar (filled) | `#00B14F` → gradient to lighter green |
| Progress bar (unfilled) | `#E0E0E0` (light gray) |
| Status title | `#000000` (black) or `#FFFFFF` (dark mode) |
| Status body | `#666666` (gray) |
| Time highlight | `#00B14F` (green, e.g., "10:02 PM") |
| Destination pin | `#FF0000` (red) |

---

## 8. Best Practices & Constraints

### 8.1 Do's

- **Keep updates meaningful** — only push when status actually changes
- **Use progress bars** — users want visual indication of progress
- **Show ETA** — estimated time is the most valuable info for delivery tracking
- **Keep text short** — notification space is limited (especially collapsed view)
- **Handle offline gracefully** — cache last state, update when connectivity returns
- **End activities promptly** — don't leave stale activities on lock screen
- **Test on real devices** — emulator behavior differs from physical devices
- **Use platform-appropriate approach** — ActivityKit on iOS, ProgressStyle on Android 16+, RemoteViews on older Android

### 8.2 Don'ts

- **Don't spam updates** — max 1 update per meaningful status change
- **Don't use for marketing** — Live Activities are for user-initiated tasks ONLY
- **Don't exceed payload limits** — 4KB for iOS content-state
- **Don't use custom fonts in Android notifications** — system fonts only
- **Don't repost dismissed notifications** — if user dismisses, respect that
- **Don't block main thread** — all notification operations should be async
- **Don't forget to handle token refresh** — push tokens can change

### 8.3 Platform-Specific Gotchas

**iOS:**
- Max 2 simultaneous Live Activities per app
- Activities auto-expire after 8 hours
- Push-to-start requires iOS 17.2+
- Widget Extension runs in separate process (can't access main app directly)
- Use App Groups (UserDefaults) to share data between app and widget

**Android:**
- RemoteViews collapsed max: 48dp height
- RemoteViews expanded max: 252dp height
- No custom RemoteViews allowed for Android 16+ Live Updates (ProgressStyle only)
- OEMs may enforce additional restrictions
- `POST_PROMOTED_NOTIFICATIONS` is non-runtime (declared in manifest, user controls in settings)

**Flutter:**
- Native code required on both platforms (Swift for iOS, Kotlin for Android)
- Plugin `live_activities` handles most boilerplate but still needs native setup
- Data passes as `Map<String, dynamic>` — keep values simple (String, int, double, bool)
- Test on both platforms separately — behavior differs significantly

---

## 9. Reference Links

### Official Documentation
- [Apple ActivityKit Documentation](https://developer.apple.com/documentation/ActivityKit/)
- [Apple — Starting and Updating Live Activities with Push](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications)
- [Android — Live Update Notifications](https://developer.android.com/develop/ui/views/notifications/live-update)
- [Android — Progress-centric Notifications (Android 16)](https://developer.android.com/about/versions/16/features/progress-centric-notifications)

### Grab Engineering
- [Grab — Bringing Live Activity to Android](https://engineering.grab.com/live-activity-2)

### Flutter Packages
- [live_activities (istornz)](https://github.com/istornz/flutter_live_activities) — iOS + Android support
- [flutter_live_activities (fluttercandies)](https://github.com/fluttercandies/flutter_live_activities)
- [live_activities on pub.dev](https://pub.dev/packages/live_activities)

### Tutorials & Guides
- [Mastering Live Activities in iOS (Medium)](https://medium.com/@gauravharkhani01/mastering-live-activities-in-ios-the-complete-developers-guide-5357eb35d520)
- [Live Activities: Architecture to Business Impact (DEV)](https://dev.to/arshtechpro/mastering-live-activities-in-ios-from-architecture-to-business-impact-2c4h)
- [Flutter Live Activity on Android (Medium)](https://medium.com/@matheusdeveloper.henrique/live-activity-on-flutter-android-an-alternative-implementation-1e16bec1fbd8)
- [Android Live Update Notification (Medium)](https://medium.com/@KaushalVasava/live-update-notification-in-android-16-15c0a810849e)
- [OneSignal — Android Live Notifications](https://documentation.onesignal.com/docs/en/android-live-notifications)

### Sample Code
- [Google — Android Live Updates Sample](https://github.com/android/platform-samples/tree/main/samples/user-interface/live-updates)
- [Live-Notification-Android (GitHub)](https://github.com/r1n1os/Live-Notification-Android)
- [Grab-style Custom Notification Clone (GitHub)](https://github.com/dekzitfz/ProgressNotif)

---

## Quick Decision Matrix

```
Q: Which approach should I use?

┌─────────────────────┬───────────────────────────────────┐
│ Scenario            │ Recommended Approach              │
├─────────────────────┼───────────────────────────────────┤
│ iOS only            │ ActivityKit (native)              │
│ Android 16+ only    │ ProgressStyle (native)            │
│ Android < 16        │ Custom Notification + RemoteViews │
│ Flutter (both)      │ live_activities package           │
│ Flutter (max ctrl)  │ Platform Channels + native code   │
│ Need push updates   │ APNS (iOS) + FCM (Android)       │
│ Offline-first       │ Local updates, sync when online   │
└─────────────────────┴───────────────────────────────────┘
```

---

*This guide was compiled from Grab's engineering blog, Apple's ActivityKit documentation,
Android's Live Update API docs, and Flutter community packages. Last updated: February 2026.*
