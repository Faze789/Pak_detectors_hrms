# Recruitment Screen Implementation Plan

## Current Status
- [x] Analyzed all relevant files (models, services, viewmodel, widgets)
- [x] Created detailed implementation plan
- [x] User approved plan

## Implementation Steps

### 1. Enhance JobViewModel (lib/viewmodels/job_viewmodel.dart)
- [ ] Add filteredJobs getter with search/department/status filters
- [ ] Add static departments list getter
- [ ] Ensure addJob properly refreshes data

### 2. Update Recruitment Widgets (lib/widgets/recruitment_widgets.dart)  
- [ ] Create JobCard widget (job header + candidates DataTable)
- [ ] Create JobFormDialog (bottom sheet for add job)

### 3. Implement Main Screen (lib/views/HR_views/hr_recruitment_screen.dart)
- [ ] Replace stub with full RecruitmentScreen
- [ ] Header + Add Job button
- [ ] Conditional Add Job form
- [ ] Filters row (search, department, status dropdowns)
- [ ] Job list with JobCard widgets
- [ ] Empty state handling
- [ ] Responsive layout

### 4. Testing & Verification
- [ ] Run `flutter pub get`
- [ ] Run `flutter analyze` 
- [ ] Test `flutter run` - verify:
  * Mock data loads
  * Add job functionality
  * Search/filter works
  * Responsive layout
- [ ] Navigate to job_detail_screen.dart integration

## Next Step: Start with Step 1 - JobViewModel enhancements