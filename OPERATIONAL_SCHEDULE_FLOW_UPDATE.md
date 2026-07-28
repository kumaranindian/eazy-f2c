# Operational Schedule Flow - Updated with Delivery Slots

## Overview
The operational schedule has been updated to include delivery slot configuration. This allows admins to specify when customers can view products AND when those products will be delivered.

## Updated Model Fields

### New Fields Added to `OperationalScheduleModel`:
```dart
// Delivery slot fields
@Default(ScheduleRecurrenceType.oneTime) ScheduleRecurrenceType deliverySlotType,
DateTime? deliveryDate, // For one-time delivery
String? deliveryStartTime, // For daily/weekly delivery
String? deliveryEndTime, // For daily/weekly delivery
@Default([]) List<int> deliveryDaysOfWeek, // For weekly delivery: 1=Monday, 2=Tuesday, etc.
```

## 6-Step Wizard Flow

### Step 1: Product Visibility Schedule (Date & Time)
**Purpose**: Define when customers can VIEW and PURCHASE products
- Select date (for one-time) or recurrence pattern
- Select time range (start time - end time)
- Choose recurrence type:
  - **One-time**: Single date
  - **Daily**: Every day
  - **Weekly**: Specific days of the week
  - **Custom Days**: Select specific days

**Fields**:
- `scheduledDate`: DateTime
- `startTime`: String (HH:mm format)
- `endTime`: String (HH:mm format)
- `recurrenceType`: ScheduleRecurrenceType enum
- `recurrenceDaysOfWeek`: List<int> (1=Mon, 2=Tue, etc.)
- `recurrenceEndDate`: DateTime (optional, for recurring schedules)

### Step 2: Location Selection (Branch, Hub, Apartments)
**Purpose**: Define WHERE products will be available
- Select Branch
- Select Hub within branch
- Choose visibility scope:
  - **Entire Hub**: All apartments in the hub
  - **Selected Apartments**: Specific apartments only

**Fields**:
- `branchId`: String
- `branchName`: String
- `hubId`: String
- `hubName`: String
- `visibilityScope`: ScheduleVisibilityScope enum
- `selectedApartmentIds`: List<String>
- `selectedApartmentNames`: List<String>

### Step 3: Farmer Selection
**Purpose**: Select which farmers' products to include
- Multi-select farmers
- Shows farmer name and location
- Can select multiple farmers

**Fields**:
- Stored in `products` list with `farmerId` and `farmerName`

### Step 4: Product Selection
**Purpose**: Select specific products from chosen farmers
- Shows products grouped by farmer
- Set quantity for each product
- Shows product details (name, category, price, unit)

**Fields**:
- `products`: List<ScheduleProductItem>
  - `productId`: String
  - `productName`: String
  - `productCategory`: String
  - `quantity`: int
  - `farmerId`: String?
  - `farmerName`: String?

### Step 5: Delivery Slot Configuration
**Purpose**: Define WHEN products will be DELIVERED
- Choose delivery slot type:
  - **Once**: Single delivery date
  - **Daily**: Delivery every day
  - **Weekly**: Delivery on specific days of the week

**Fields**:
- `deliverySlotType`: ScheduleRecurrenceType enum
- `deliveryDate`: DateTime (for one-time delivery)
- `deliveryStartTime`: String (for daily/weekly)
- `deliveryEndTime`: String (for daily/weekly)
- `deliveryDaysOfWeek`: List<int> (for weekly: 1=Mon, 2=Tue, etc.)

### Step 6: Summary & Confirmation
**Purpose**: Review all details before creating schedule
- Shows all selected information
- Product visibility schedule
- Location details
- Selected farmers
- Selected products with quantities
- Delivery slot details
- Option to go back and edit any step

## Example Scenarios

### Scenario 1: Weekly Visibility, Saturday Delivery
**Product Visibility**: Mon, Tue, Wed (customers can see and order)
**Delivery**: Saturday (products delivered)

```dart
// Product visibility
recurrenceType: ScheduleRecurrenceType.weekly
recurrenceDaysOfWeek: [1, 2, 3] // Mon, Tue, Wed
startTime: "04:00"
endTime: "23:00"

// Delivery slot
deliverySlotType: ScheduleRecurrenceType.weekly
deliveryDaysOfWeek: [6] // Saturday
deliveryStartTime: "08:00"
deliveryEndTime: "18:00"
```

### Scenario 2: Daily Visibility, Daily Delivery
**Product Visibility**: Every day (customers can see and order)
**Delivery**: Every day (products delivered daily)

```dart
// Product visibility
recurrenceType: ScheduleRecurrenceType.daily
startTime: "04:00"
endTime: "23:00"

// Delivery slot
deliverySlotType: ScheduleRecurrenceType.daily
deliveryStartTime: "08:00"
deliveryEndTime: "18:00"
```

### Scenario 3: One-time Visibility, Scheduled Delivery
**Product Visibility**: Single date (customers can see and order)
**Delivery**: Specific delivery date

```dart
// Product visibility
recurrenceType: ScheduleRecurrenceType.oneTime
scheduledDate: DateTime(2026, 7, 15)
startTime: "04:00"
endTime: "23:00"

// Delivery slot
deliverySlotType: ScheduleRecurrenceType.oneTime
deliveryDate: DateTime(2026, 7, 18) // 3 days later
```

## Implementation Tasks

### 1. Update Model (✅ COMPLETED)
- [x] Add delivery slot fields to `OperationalScheduleModel`
- [x] Update `fromFirestore` method
- [x] Update `toFirestore` method
- [x] Run build_runner to regenerate freezed files

### 2. Update Wizard UI (TODO)
- [ ] Update step count from 4 to 6
- [ ] Add Step 5: Delivery Slot Configuration UI
- [ ] Update Step 6: Summary to include delivery slot details
- [ ] Add validation for delivery slot fields
- [ ] Update navigation logic

### 3. Update Repository (TODO)
- [ ] Ensure delivery slot fields are saved correctly
- [ ] Add validation for delivery slot logic

### 4. Update Customer View (TODO)
- [ ] Filter products based on visibility schedule
- [ ] Show delivery slot information to customers
- [ ] Update order placement to include delivery slot details

### 5. Update Firestore Rules (TODO)
- [ ] Ensure new fields are allowed in security rules

### 6. Update Firestore Indexes (TODO)
- [ ] Add indexes for delivery slot queries if needed

## UI Components Needed

### Step 5: Delivery Slot Configuration
```dart
Widget _buildStep5DeliverySlot() {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Delivery slot type selector
        SegmentedButton<ScheduleRecurrenceType>(
          segments: [
            ButtonSegment(value: ScheduleRecurrenceType.oneTime, label: Text('Once')),
            ButtonSegment(value: ScheduleRecurrenceType.daily, label: Text('Daily')),
            ButtonSegment(value: ScheduleRecurrenceType.weekly, label: Text('Weekly')),
          ],
          selected: {_deliverySlotType},
          onSelectionChanged: (Set<ScheduleRecurrenceType> newSelection) {
            setState(() => _deliverySlotType = newSelection.first);
          },
        ),
        
        // Conditional UI based on delivery slot type
        if (_deliverySlotType == ScheduleRecurrenceType.oneTime)
          _buildOnceDeliveryUI(),
        if (_deliverySlotType == ScheduleRecurrenceType.daily)
          _buildDailyDeliveryUI(),
        if (_deliverySlotType == ScheduleRecurrenceType.weekly)
          _buildWeeklyDeliveryUI(),
      ],
    ),
  );
}
```

## Database Schema

### Firestore Document Structure
```json
{
  "scheduledDate": Timestamp,
  "startTime": "04:00",
  "endTime": "23:00",
  "recurrenceType": "weekly",
  "recurrenceDaysOfWeek": [1, 2, 3],
  "recurrenceEndDate": Timestamp,
  
  "deliverySlotType": "weekly",
  "deliveryDaysOfWeek": [6],
  "deliveryStartTime": "08:00",
  "deliveryEndTime": "18:00",
  "deliveryDate": null,
  
  "branchId": "branch123",
  "hubId": "hub456",
  "products": [...],
  ...
}
```

## Next Steps
1. Run build_runner to regenerate model files
2. Update the wizard UI to include Step 5 (Delivery Slot)
3. Update Step 6 (Summary) to show delivery slot details
4. Test all scenarios
5. Update customer-facing UI to show delivery information
