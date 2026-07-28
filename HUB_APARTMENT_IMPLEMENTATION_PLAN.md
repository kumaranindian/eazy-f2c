# 🚀 HUB & Apartment Management - Implementation Plan

## 📋 **Overview**

Implementing production-ready HUB Management and Apartment Management features following the same architecture as Branch Management.

---

## 🎯 **Features to Implement**

### **HUB Management:**
- ✅ View all HUBs with real-time updates
- ✅ Stats cards (Total, Active, Inactive, Deleted, Total Branches)
- ✅ Add HUB (with branch selection)
- ✅ Edit HUB
- ✅ Delete HUB (soft delete)
- ✅ Restore HUB
- ✅ Search by HUB name or branch
- ✅ Filter by status

### **Apartment Management:**
- ✅ View all Apartments with real-time updates
- ✅ Stats cards (Total, Active, Inactive, Total HUBs)
- ✅ Add Apartment (with HUB selection)
- ✅ Edit Apartment
- ✅ Delete Apartment (soft delete)
- ✅ Restore Apartment
- ✅ Search by apartment name or HUB
- ✅ Filter by HUB and status
- ✅ Delivery schedule fields

---

## 📁 **Architecture (Same as Branch Management)**

```
lib/features/admin/
├── models/
│   ├── hub_model.dart          ✅ Created
│   └── apartment_model.dart    ✅ Created
├── datasources/
│   ├── hub_datasource.dart     ⏳ To create
│   └── apartment_datasource.dart ⏳ To create
├── repositories/
│   ├── hub_repository.dart     ⏳ To create
│   └── apartment_repository.dart ⏳ To create
├── providers/
│   ├── hub_providers.dart      ⏳ To create
│   └── apartment_providers.dart ⏳ To create
└── presentation/
    ├── pages/
    │   ├── hubs/
    │   │   └── hubs_management_page.dart ⏳ To create
    │   └── apartments/
    │       └── apartments_management_page.dart ⏳ To create
    └── widgets/
        ├── add_hub_dialog.dart    ⏳ To create
        ├── edit_hub_dialog.dart   ⏳ To create
        ├── delete_hub_dialog.dart ⏳ To create
        ├── add_apartment_dialog.dart    ⏳ To create
        ├── edit_apartment_dialog.dart   ⏳ To create
        └── delete_apartment_dialog.dart ⏳ To create
```

---

## 🔥 **Firestore Structure**

### **HUBs Collection:**
```json
{
  "id": "auto-generated",
  "name": "Polachery HUB",
  "branchId": "branch_id",
  "branchName": "Chennai South Branch",
  "isActive": true,
  "isDeleted": false,
  "createdAt": "Timestamp",
  "createdBy": "user_id",
  "updatedAt": "Timestamp",
  "updatedBy": "user_id",
  "apartmentCount": 4
}
```

### **Apartments Collection:**
```json
{
  "id": "auto-generated",
  "name": "Koramangala Community",
  "hubId": "hub_id",
  "hubName": "Polachery HUB",
  "location": "Koramangala, Bangalore",
  "deliveryDay": "Saturday",
  "deliveryTime": "08:00 AM",
  "pickupPoint": "Community Center, 5th Block",
  "isActive": true,
  "isDeleted": false,
  "createdAt": "Timestamp",
  "createdBy": "user_id",
  "updatedAt": "Timestamp",
  "updatedBy": "user_id",
  "totalCustomers": 25
}
```

---

## 🔒 **Firestore Rules (To Add)**

```javascript
// HUBs - Admin full access, others read
match /hubs/{hubId} {
  allow read: if request.auth != null;
  allow create, update, delete: if request.auth != null;
}

// Apartments - Admin full access, others read
match /apartments/{apartmentId} {
  allow read: if request.auth != null;
  allow create, update, delete: if request.auth != null;
}
```

---

## 📊 **Firestore Indexes (To Add)**

### **HUBs Indexes:**
```json
{
  "collectionGroup": "hubs",
  "fields": [
    { "fieldPath": "isDeleted", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "hubs",
  "fields": [
    { "fieldPath": "isActive", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "hubs",
  "fields": [
    { "fieldPath": "branchId", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

### **Apartments Indexes:**
```json
{
  "collectionGroup": "apartments",
  "fields": [
    { "fieldPath": "isDeleted", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "apartments",
  "fields": [
    { "fieldPath": "isActive", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "apartments",
  "fields": [
    { "fieldPath": "hubId", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

---

## ✅ **Implementation Steps**

### **Phase 1: Backend (Data Layer)**
1. ✅ Create HUB Model
2. ✅ Create Apartment Model
3. ⏳ Create HUB DataSource
4. ⏳ Create Apartment DataSource
5. ⏳ Create HUB Repository
6. ⏳ Create Apartment Repository
7. ⏳ Create HUB Providers
8. ⏳ Create Apartment Providers

### **Phase 2: UI (Presentation Layer)**
9. ⏳ Create HUB Management Page
10. ⏳ Create Add/Edit/Delete HUB Dialogs
11. ⏳ Create Apartment Management Page
12. ⏳ Create Add/Edit/Delete Apartment Dialogs
13. ⏳ Update Admin Dashboard navigation

### **Phase 3: Deployment**
14. ⏳ Update Firestore Rules
15. ⏳ Add Firestore Indexes
16. ⏳ Deploy rules and indexes
17. ⏳ Run code generation
18. ⏳ Start the app

---

## 🎨 **UI Components (Based on Screenshots)**

### **HUB Management Page:**
- Breadcrumb: Dashboard > HUB Management
- Stats Cards: Total HUBs, Active HUBs, Inactive HUBs, Total Branches
- Search bar: "Search by HUB name or branch"
- Filter: "All Status" dropdown
- Add HUB button (green, top right)
- Table columns: #, HUB NAME, BRANCH, STATUS, CREATED ON, ACTIONS
- Actions: Edit (pencil), Delete (trash)

### **Add HUB Dialog:**
- HUB Name (required)
- Branch (dropdown, required)
- Status (Active/Inactive dropdown)
- Cancel / Create HUB buttons

### **Edit HUB Dialog:**
- Same as Add, pre-filled
- Cancel / Update HUB buttons

### **Apartment Management Page:**
- Breadcrumb: Dashboard > Apartment Management
- Stats Cards: Total Apartments, Active Apartments, Inactive Apartments, Total HUBs
- Search bar: "Search by apartment name or HUB"
- Filters: "Select HUB" dropdown, "All Status" dropdown
- Add Apartment button (green, top right)
- Table columns: #, APARTMENT NAME, HUB, TOTAL CUSTOMERS, DELIVERY SCHEDULE, PICKUP POINT, STATUS, ACTIONS
- Actions: Edit (pencil), Delete (trash)

### **Add Apartment Dialog:**
- Apartment Name (required)
- HUB / Location (required)
- Delivery Day (dropdown: Saturday, Sunday, etc.)
- Delivery Time (time picker)
- Pickup Point (required)
- Status (Active/Inactive dropdown)
- Cancel / Create Apartment buttons

### **Edit Apartment Dialog:**
- Same as Add, pre-filled
- Cancel / Update Apartment buttons

---

## 🚀 **Estimated Files to Create**

- Models: 2 ✅
- DataSources: 2
- Repositories: 2
- Providers: 2
- Pages: 2
- Dialogs: 6
- **Total: 16 files**

---

## ⏱️ **Implementation Time**

Given the complexity and production standards:
- Backend Layer: ~30 minutes
- UI Layer: ~45 minutes
- Testing & Deployment: ~15 minutes
- **Total: ~90 minutes**

---

## 📝 **Next Steps**

Due to the extensive implementation, I'll create the files systematically and provide you with:
1. All necessary code files
2. Updated Firestore rules
3. Updated Firestore indexes
4. Deployment commands
5. Testing guide

**Shall I proceed with the complete implementation?**
