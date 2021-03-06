/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "SettingsViewController.h"

#import <MatrixKit/MatrixKit.h>

#import <OLMKit/OLMKit.h>

#import "AppDelegate.h"
#import "AvatarGenerator.h"

#import "BugReportViewController.h"

#import "WebViewViewController.h"

#import "CountryPickerViewController.h"
#import "LanguagePickerViewController.h"
#import "DeactivateAccountViewController.h"
#import "SecurityViewController.h"

#import "NBPhoneNumberUtil.h"
#import "RageShakeManager.h"
#import "ThemeService.h"
#import "TableViewCellWithPhoneNumberTextField.h"

#import "GroupsDataSource.h"
#import "GroupTableViewCellWithSwitch.h"

#import "Row.h"
#import "Section.h"

#import "GBDeviceInfo_iOS.h"

#import "Riot-Swift.h"

NSString* const kSettingsViewControllerPhoneBookCountryCellId = @"kSettingsViewControllerPhoneBookCountryCellId";

enum
{
    SECTION_TAG_SIGN_OUT = 0,
    SECTION_TAG_USER_SETTINGS,
    SECTION_TAG_SECURITY,
    SECTION_TAG_IGNORED_USERS,
    SECTION_TAG_USER_INTERFACE,
    SECTION_TAG_FLAIR,
    SECTION_TAG_DEACTIVATE_ACCOUNT
};

enum
{
    USER_SETTINGS_PROFILE_PICTURE_INDEX = 0,
    USER_SETTINGS_DISPLAYNAME_INDEX,
    USER_SETTINGS_FIRST_NAME_INDEX,
    USER_SETTINGS_SURNAME_INDEX
};

enum
{
    USER_SETTINGS_EMAILS_OFFSET = 2000,
    USER_SETTINGS_PHONENUMBERS_OFFSET = 1000
};

enum
{
    INTEGRATIONS_INDEX,
    INTEGRATIONS_DESCRIPTION_INDEX,
};

enum {
    LOCAL_CONTACTS_SYNC_INDEX,
    LOCAL_CONTACTS_PHONEBOOK_COUNTRY_INDEX
};

enum
{
    USER_INTERFACE_LANGUAGE_INDEX = 0,
    USER_INTERFACE_THEME_INDEX,
};

enum
{
    IDENTITY_SERVER_INDEX,
    IDENTITY_SERVER_DESCRIPTION_INDEX,
};

enum
{
    OTHER_VERSION_INDEX = 0,
    OTHER_OLM_VERSION_INDEX,
    OTHER_COPYRIGHT_INDEX,
    OTHER_TERM_CONDITIONS_INDEX,
    OTHER_PRIVACY_INDEX,
    OTHER_THIRD_PARTY_INDEX,
    OTHER_CRASH_REPORT_INDEX,
    OTHER_ENABLE_RAGESHAKE_INDEX,
    OTHER_MARK_ALL_AS_READ_INDEX,
    OTHER_CLEAR_CACHE_INDEX,
    OTHER_REPORT_BUG_INDEX,
};

enum
{
    LABS_USE_JITSI_WIDGET_INDEX = 0,
};

enum
{
    SECURITY_BUTTON_INDEX = 0,
};

typedef void (^blockSettingsViewController_onReadyToDestroy)(void);

#pragma mark - SettingsViewController

@interface SettingsViewController () <DeactivateAccountViewControllerDelegate,
SecureBackupSetupCoordinatorBridgePresenterDelegate,
SignOutAlertPresenterDelegate,
SingleImagePickerPresenterDelegate,
SettingsDiscoveryTableViewSectionDelegate, SettingsDiscoveryViewModelCoordinatorDelegate,
SettingsIdentityServerCoordinatorBridgePresenterDelegate>
{
    // Current alert (if any).
    UIAlertController *currentAlert;

    // listener
    id removedAccountObserver;
    id accountUserInfoObserver;
    id pushInfoUpdateObserver;
    
    id notificationCenterWillUpdateObserver;
    id notificationCenterDidUpdateObserver;
    id notificationCenterDidFailObserver;
    
    // profile updates
    // avatar
    UIImage* newAvatarImage;
    // the avatar image has been uploaded
    NSString* uploadedAvatarURL;
    
    // new display name
    NSString* newDisplayName;
    
    // password update
    UITextField* currentPasswordTextField;
    UITextField* newPasswordTextField1;
    UITextField* newPasswordTextField2;
    UIAlertAction* savePasswordAction;

    // New email address to bind
    UITextField* newEmailTextField;
    
    // New phone number to bind
    TableViewCellWithPhoneNumberTextField * newPhoneNumberCell;
    CountryPickerViewController *newPhoneNumberCountryPicker;
    NBPhoneNumber *newPhoneNumber;
    
    // Flair: the groups data source
    GroupsDataSource *groupsDataSource;
    
    // Observe kAppDelegateDidTapStatusBarNotification to handle tap on clock status bar.
    id kAppDelegateDidTapStatusBarNotificationObserver;
    
    // Observe kThemeServiceDidChangeThemeNotification to handle user interface theme change.
    id kThemeServiceDidChangeThemeNotificationObserver;
    
    // Postpone destroy operation when saving, pwd reset or email binding is in progress
    BOOL isSavingInProgress;
    BOOL isResetPwdInProgress;
    BOOL is3PIDBindingInProgress;
    blockSettingsViewController_onReadyToDestroy onReadyToDestroyHandler;
    
    //
    UIAlertController *resetPwdAlertController;
    
    BOOL keepNewEmailEditing;
    BOOL keepNewPhoneNumberEditing;
    
    // The current pushed view controller
    UIViewController *pushedViewController;

    SettingsIdentityServerCoordinatorBridgePresenter *identityServerSettingsCoordinatorBridgePresenter;
}

/**
 Flag indicating whether the user is typing an email to bind.
 */
@property (nonatomic) BOOL newEmailEditingEnabled;

/**
 Flag indicating whether the user is typing a phone number to bind.
 */
@property (nonatomic) BOOL newPhoneEditingEnabled;

@property (nonatomic, weak) DeactivateAccountViewController *deactivateAccountViewController;
@property (nonatomic, strong) SignOutAlertPresenter *signOutAlertPresenter;
@property (nonatomic, weak) UIButton *signOutButton;
@property (nonatomic, strong) SingleImagePickerPresenter *imagePickerPresenter;

@property (nonatomic, strong) SettingsDiscoveryViewModel *settingsDiscoveryViewModel;
@property (nonatomic, strong) SettingsDiscoveryTableViewSection *settingsDiscoveryTableViewSection;
@property (nonatomic, strong) SettingsDiscoveryThreePidDetailsCoordinatorBridgePresenter *discoveryThreePidDetailsPresenter;

@property (nonatomic, strong) SecureBackupSetupCoordinatorBridgePresenter *secureBackupSetupCoordinatorBridgePresenter;
@property (nonatomic, strong) AuthenticatedSessionViewControllerFactory *authenticatedSessionViewControllerFactory;

@property (nonatomic, strong) NSArray<Section*> *sections;

@end

@implementation SettingsViewController

+ (instancetype)instantiate
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    SettingsViewController *settingsViewController = [storyboard instantiateViewControllerWithIdentifier:@"SettingsViewController"];
    return settingsViewController;
}

- (void)finalizeInit
{
    [super finalizeInit];
    
    // Setup `MXKViewControllerHandling` properties
    self.enableBarTintColorStatusChange = NO;
    self.rageShakeManager = [RageShakeManager sharedManager];
    
    isSavingInProgress = NO;
    isResetPwdInProgress = NO;
    is3PIDBindingInProgress = NO;
}

- (void)updateSections
{
    NSMutableArray<Section*> *tmpSections = [NSMutableArray arrayWithCapacity:SECTION_TAG_DEACTIVATE_ACCOUNT + 1];
    
    Section *sectionSignOut = [Section sectionWithTag:SECTION_TAG_SIGN_OUT];
    [sectionSignOut addRowWithTag:0];
    [tmpSections addObject:sectionSignOut];
    
    Section *sectionUserSettings = [Section sectionWithTag:SECTION_TAG_USER_SETTINGS];
    [sectionUserSettings addRowWithTag:USER_SETTINGS_PROFILE_PICTURE_INDEX];
    [sectionUserSettings addRowWithTag:USER_SETTINGS_DISPLAYNAME_INDEX];
    if (BuildSettings.settingsScreenShowUserFirstName)
    {
        [sectionUserSettings addRowWithTag:USER_SETTINGS_FIRST_NAME_INDEX];
    }
    if (BuildSettings.settingsScreenShowUserSurname)
    {
        [sectionUserSettings addRowWithTag:USER_SETTINGS_SURNAME_INDEX];
    }
    MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;
    //  add linked emails
    for (NSInteger index = 0; index < account.linkedEmails.count; index++)
    {
        [sectionUserSettings addRowWithTag: USER_SETTINGS_EMAILS_OFFSET + index];
    }
    //  add linked phone numbers
    for (NSInteger index = 0; index < account.linkedPhoneNumbers.count; index++)
    {
        [sectionUserSettings addRowWithTag: USER_SETTINGS_PHONENUMBERS_OFFSET + index];
    }
    sectionUserSettings.headerTitle = NSLocalizedStringFromTable(@"settings_user_settings", @"Vector", nil);
    [tmpSections addObject:sectionUserSettings];
    
    Section *sectionSecurity = [Section sectionWithTag:SECTION_TAG_SECURITY];
    [sectionSecurity addRowWithTag:SECURITY_BUTTON_INDEX];
    sectionSecurity.headerTitle = NSLocalizedStringFromTable(@"settings_security", @"Vector", nil);
    [tmpSections addObject:sectionSecurity];
    
    MXSession *session = [AppDelegate theDelegate].mxSessions.firstObject;
    if (session.ignoredUsers.count)
    {
        Section *sectionIgnoredUsers = [Section sectionWithTag:SECTION_TAG_IGNORED_USERS];
        for (NSInteger index = 0; index < session.ignoredUsers.count; index++)
        {
            [sectionIgnoredUsers addRowWithTag:index];
        }
        sectionIgnoredUsers.headerTitle = NSLocalizedStringFromTable(@"settings_ignored_users", @"Vector", nil);
        [tmpSections addObject:sectionIgnoredUsers];
    }
    
    Section *sectionUserInterface = [Section sectionWithTag:SECTION_TAG_USER_INTERFACE];
    [sectionUserInterface addRowWithTag:USER_INTERFACE_LANGUAGE_INDEX];
    [sectionUserInterface addRowWithTag:USER_INTERFACE_THEME_INDEX];
    sectionUserInterface.headerTitle = NSLocalizedStringFromTable(@"settings_user_interface", @"Vector", nil);
    [tmpSections addObject: sectionUserInterface];
  
    if ([groupsDataSource numberOfSectionsInTableView:self.tableView] && groupsDataSource.joinedGroupsSection != -1)
    {
        NSInteger count = [groupsDataSource tableView:self.tableView
                                numberOfRowsInSection:groupsDataSource.joinedGroupsSection];
        Section *sectionFlair = [Section sectionWithTag:SECTION_TAG_FLAIR];
        for (NSInteger index = 0; index < count; index++)
        {
            [sectionFlair addRowWithTag:index];
        }
        sectionFlair.headerTitle = NSLocalizedStringFromTable(@"settings_flair", @"Vector", nil);
        [tmpSections addObject:sectionFlair];
    }
    
    if (BuildSettings.settingsScreenAllowDeactivatingAccount)
    {
        Section *sectionDeactivate = [Section sectionWithTag:SECTION_TAG_DEACTIVATE_ACCOUNT];
        [sectionDeactivate addRowWithTag:0];
        sectionDeactivate.headerTitle = NSLocalizedStringFromTable(@"settings_deactivate_my_account", @"Vector", nil);
        [tmpSections addObject:sectionDeactivate];
    }
    
    //  update sections
    self.sections = tmpSections;
}

- (void)setSections:(NSArray<Section *> *)sections
{
    _sections = sections;
    
    //  reload table
    [self.tableView reloadData];
}

/// Returns index of section for the given tag. If cannot find, return `NSNotFound`
/// @param tag Tag for section
- (NSInteger)indexOfSectionForTag:(NSInteger)tag
{
    return [_sections indexOfObjectPassingTest:^BOOL(Section * _Nonnull section, NSUInteger idx, BOOL * _Nonnull stop) {
        return section.tag == tag;
    }];
}

/// Finds the exact indexpath for the given row and section tag. If cannot find, returns nil
/// @param rowTag Tag for row
/// @param sectionTag Tag for section
- (NSIndexPath *)exactIndexPathForRowTag:(NSInteger)rowTag sectionTag:(NSInteger)sectionTag
{
    NSInteger sectionIndex = [self indexOfSectionForTag:sectionTag];
    if (sectionIndex != NSNotFound)
    {
        Section *section = _sections[sectionIndex];
        NSInteger rowIndex = [section indexOfRowForTag:rowTag];
        if (rowIndex != NSNotFound)
        {
            return [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex];
        }
    }
    return nil;
}

/// Finds the nearest next indexPath for given row tag and section tag. If the section finishes, also checks for the next section. If cannot find any row available, returns nil.
/// @param rowTag Tag for row
/// @param sectionTag Tag for section
- (NSIndexPath *)nearestIndexPathForRowTag:(NSInteger)rowTag sectionTag:(NSInteger)sectionTag
{
    NSInteger sectionIndex = [self indexOfSectionForTag:sectionTag];
    if (sectionIndex != NSNotFound)
    {
        Section *section = _sections[sectionIndex];
        NSInteger rowIndex = [section indexOfRowForTag:rowTag];
        if (rowIndex != NSNotFound)
        {
            //  exact row found, return it
            return [NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex];
        }
        else if (rowTag + 1 < section.rows.count)
        {
            //  try to return next row in the same section
            return [self nearestIndexPathForRowTag:rowTag + 1 sectionTag:sectionTag];
        }
        else if (sectionTag + 1 < _sections.count)
        {
            //  try to return the first row of the next section
            return [self nearestIndexPathForRowTag:0 sectionTag:sectionTag + 1];
        }
        
        return nil;
    }
    else if (sectionTag + 1 < _sections.count)
    {
        //  try to return the first row of the next section
        return [self nearestIndexPathForRowTag:0 sectionTag:sectionTag + 1];
    }
    return nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.navigationItem.title = NSLocalizedStringFromTable(@"settings_title", @"Vector", nil);
    
    // Remove back bar button title when pushing a view controller
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    
    [self.tableView registerClass:MXKTableViewCellWithLabelAndTextField.class forCellReuseIdentifier:[MXKTableViewCellWithLabelAndTextField defaultReuseIdentifier]];
    [self.tableView registerClass:MXKTableViewCellWithLabelAndSwitch.class forCellReuseIdentifier:[MXKTableViewCellWithLabelAndSwitch defaultReuseIdentifier]];
    [self.tableView registerClass:MXKTableViewCellWithLabelAndMXKImageView.class forCellReuseIdentifier:[MXKTableViewCellWithLabelAndMXKImageView defaultReuseIdentifier]];
    [self.tableView registerClass:TableViewCellWithPhoneNumberTextField.class forCellReuseIdentifier:[TableViewCellWithPhoneNumberTextField defaultReuseIdentifier]];
    [self.tableView registerClass:GroupTableViewCellWithSwitch.class forCellReuseIdentifier:[GroupTableViewCellWithSwitch defaultReuseIdentifier]];
    [self.tableView registerNib:MXKTableViewCellWithTextView.nib forCellReuseIdentifier:[MXKTableViewCellWithTextView defaultReuseIdentifier]];
    
    // Enable self sizing cells
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 50;
    
    // Add observer to handle removed accounts
    removedAccountObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKAccountManagerDidRemoveAccountNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        if ([MXKAccountManager sharedManager].accounts.count)
        {
            // Refresh table to remove this account
            [self refreshSettings];
        }
        
    }];
    
    // Add observer to handle accounts update
    accountUserInfoObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKAccountUserInfoDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self stopActivityIndicator];
        
        [self refreshSettings];
        
    }];
    
    // Add observer to push settings
    pushInfoUpdateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXKAccountAPNSActivityDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self stopActivityIndicator];
        
        [self refreshSettings];
        
    }];

    [self registerAccountDataDidChangeIdentityServerNotification];
    
    // Add each matrix session, to update the view controller appearance according to mx sessions state
    NSArray *sessions = [AppDelegate theDelegate].mxSessions;
    for (MXSession *mxSession in sessions)
    {
        [self addMatrixSession:mxSession];
    }
    
    [self setupDiscoverySection];

    groupsDataSource = [[GroupsDataSource alloc] initWithMatrixSession:self.mainSession];
    [groupsDataSource finalizeInitialization];
    groupsDataSource.delegate = self;
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(onSave:)];
    self.navigationItem.rightBarButtonItem.accessibilityIdentifier=@"SettingsVCNavBarSaveButton";

    
    // Observe user interface theme change.
    kThemeServiceDidChangeThemeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kThemeServiceDidChangeThemeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self userInterfaceThemeDidChange];
        
    }];
    [self userInterfaceThemeDidChange];
    
    self.signOutAlertPresenter = [SignOutAlertPresenter new];
    self.signOutAlertPresenter.delegate = self;
    
    [self updateSections];
}

- (void)userInterfaceThemeDidChange
{
    [ThemeService.shared.theme applyStyleOnNavigationBar:self.navigationController.navigationBar];

    self.activityIndicator.backgroundColor = ThemeService.shared.theme.overlayBackgroundColor;
    
    // Check the table view style to select its bg color.
    self.tableView.backgroundColor = ((self.tableView.style == UITableViewStylePlain) ? ThemeService.shared.theme.backgroundColor : ThemeService.shared.theme.headerBackgroundColor);
    self.view.backgroundColor = self.tableView.backgroundColor;
    self.tableView.separatorColor = ThemeService.shared.theme.lineBreakColor;
    
    if (self.tableView.dataSource)
    {
        [self refreshSettings];
    }

    [self setNeedsStatusBarAppearanceUpdate];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return ThemeService.shared.theme.statusBarStyle;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)destroy
{
    if (groupsDataSource)
    {
        groupsDataSource.delegate = nil;
        [groupsDataSource destroy];
        groupsDataSource = nil;
    }
    
    // Release the potential pushed view controller
    [self releasePushedViewController];
    
    if (kThemeServiceDidChangeThemeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kThemeServiceDidChangeThemeNotificationObserver];
        kThemeServiceDidChangeThemeNotificationObserver = nil;
    }

    if (isSavingInProgress || isResetPwdInProgress || is3PIDBindingInProgress)
    {
        __weak typeof(self) weakSelf = self;
        onReadyToDestroyHandler = ^() {
            
            if (weakSelf)
            {
                typeof(self) self = weakSelf;
                [self destroy];
            }
            
        };
    }
    else
    {
        // Dispose all resources
        [self reset];
        
        [super destroy];
    }

    _secureBackupSetupCoordinatorBridgePresenter = nil;
    identityServerSettingsCoordinatorBridgePresenter = nil;
}

- (void)onMatrixSessionStateDidChange:(NSNotification *)notif
{
    MXSession *mxSession = notif.object;
    
    // Check whether the concerned session is a new one which is not already associated with this view controller.
    if (mxSession.state == MXSessionStateInitialised && [self.mxSessions indexOfObject:mxSession] != NSNotFound)
    {
        // Store this new session
        [self addMatrixSession:mxSession];
    }
    else
    {
        [super onMatrixSessionStateDidChange:notif];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Screen tracking
    [[Analytics sharedInstance] trackScreen:@"Settings"];
    
    // Refresh display
    [self refreshSettings];

    // Refresh linked emails and phone numbers in parallel
    [self loadAccount3PIDs];
        
    // Observe kAppDelegateDidTapStatusBarNotificationObserver.
    kAppDelegateDidTapStatusBarNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kAppDelegateDidTapStatusBarNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self.tableView setContentOffset:CGPointMake(-self.tableView.mxk_adjustedContentInset.left, -self.tableView.mxk_adjustedContentInset.top) animated:YES];
        
    }];
    
    newPhoneNumberCountryPicker = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Release the potential pushed view controller
    [self releasePushedViewController];
    
    [self.settingsDiscoveryTableViewSection reload];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
    
    if (resetPwdAlertController)
    {
        [resetPwdAlertController dismissViewControllerAnimated:NO completion:nil];
        resetPwdAlertController = nil;
    }

    if (notificationCenterWillUpdateObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:notificationCenterWillUpdateObserver];
        notificationCenterWillUpdateObserver = nil;
    }
    
    if (notificationCenterDidUpdateObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:notificationCenterDidUpdateObserver];
        notificationCenterDidUpdateObserver = nil;
    }
    
    if (notificationCenterDidFailObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:notificationCenterDidFailObserver];
        notificationCenterDidFailObserver = nil;
    }
    
    if (kAppDelegateDidTapStatusBarNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kAppDelegateDidTapStatusBarNotificationObserver];
        kAppDelegateDidTapStatusBarNotificationObserver = nil;
    }
}

#pragma mark - Internal methods

- (void)pushViewController:(UIViewController*)viewController
{
    // Keep ref on pushed view controller
    pushedViewController = viewController;
    
    // Hide back button title
    self.navigationItem.backBarButtonItem =[[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)releasePushedViewController
{
    if (pushedViewController)
    {
        if ([pushedViewController isKindOfClass:[UINavigationController class]])
        {
            UINavigationController *navigationController = (UINavigationController*)pushedViewController;
            for (id subViewController in navigationController.viewControllers)
            {
                if ([subViewController respondsToSelector:@selector(destroy)])
                {
                    [subViewController destroy];
                }
            }
        }
        else if ([pushedViewController respondsToSelector:@selector(destroy)])
        {
            [(id)pushedViewController destroy];
        }
        
        pushedViewController = nil;
    }
}

- (void)dismissKeyboard
{
    [currentPasswordTextField resignFirstResponder];
    [newPasswordTextField1 resignFirstResponder];
    [newPasswordTextField2 resignFirstResponder];
    [newEmailTextField resignFirstResponder];
    [newPhoneNumberCell.mxkTextField resignFirstResponder];
}

- (void)reset
{
    // Remove observers
    if (removedAccountObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:removedAccountObserver];
        removedAccountObserver = nil;
    }
    
    if (accountUserInfoObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:accountUserInfoObserver];
        accountUserInfoObserver = nil;
    }
    
    if (pushInfoUpdateObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:pushInfoUpdateObserver];
        pushInfoUpdateObserver = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    onReadyToDestroyHandler = nil;
}

-(void)setNewEmailEditingEnabled:(BOOL)newEmailEditingEnabled
{
    if (newEmailEditingEnabled != _newEmailEditingEnabled)
    {
        // Update the flag
        _newEmailEditingEnabled = newEmailEditingEnabled;

        if (!newEmailEditingEnabled)
        {
            // Dismiss the keyboard
            [newEmailTextField resignFirstResponder];
            newEmailTextField = nil;
        }
    }
}

-(void)setNewPhoneEditingEnabled:(BOOL)newPhoneEditingEnabled
{
    if (newPhoneEditingEnabled != _newPhoneEditingEnabled)
    {
        // Update the flag
        _newPhoneEditingEnabled = newPhoneEditingEnabled;
        
        if (!newPhoneEditingEnabled)
        {
            // Dismiss the keyboard
            [newPhoneNumberCell.mxkTextField resignFirstResponder];
            newPhoneNumberCell = nil;
        }
    }
}

- (void)showValidationEmailDialogWithMessage:(NSString*)message for3PidAddSession:(MX3PidAddSession*)threePidAddSession threePidAddManager:(MX3PidAddManager*)threePidAddManager password:(NSString*)password
{
    MXWeakify(self);
    [currentAlert dismissViewControllerAnimated:NO completion:nil];
    currentAlert = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"account_email_validation_title"] message:message preferredStyle:UIAlertControllerStyleAlert];

    [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        MXStrongifyAndReturnIfNil(self);
        self->currentAlert = nil;
        [self stopActivityIndicator];

        // Reset new email adding
        self.newEmailEditingEnabled = NO;
    }]];

    [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"continue"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        MXStrongifyAndReturnIfNil(self);
        [self tryFinaliseAddEmailSession:threePidAddSession withPassword:password threePidAddManager:threePidAddManager];
    }]];

    [currentAlert mxk_setAccessibilityIdentifier:@"SettingsVCEmailValidationAlert"];
    [self presentViewController:currentAlert animated:YES completion:nil];
}

- (void)tryFinaliseAddEmailSession:(MX3PidAddSession*)threePidAddSession withPassword:(NSString*)password threePidAddManager:(MX3PidAddManager*)threePidAddManager
{
    self->is3PIDBindingInProgress = YES;

    [threePidAddManager tryFinaliseAddEmailSession:threePidAddSession withPassword:password success:^{

        self->is3PIDBindingInProgress = NO;

        // Check whether destroy has been called during email binding
        if (self->onReadyToDestroyHandler)
        {
            // Ready to destroy
            self->onReadyToDestroyHandler();
            self->onReadyToDestroyHandler = nil;
        }
        else
        {
            self->currentAlert = nil;

            [self stopActivityIndicator];

            // Reset new email adding
            self.newEmailEditingEnabled = NO;

            // Update linked emails
            [self loadAccount3PIDs];
        }

    } failure:^(NSError * _Nonnull error) {
        NSLog(@"[SettingsViewController] tryFinaliseAddEmailSession: Failed to bind email");

        MXError *mxError = [[MXError alloc] initWithNSError:error];
        if (mxError && [mxError.errcode isEqualToString:kMXErrCodeStringForbidden])
        {
            NSLog(@"[SettingsViewController] tryFinaliseAddEmailSession: Wrong password");

            // Ask password again
            self->currentAlert = [UIAlertController alertControllerWithTitle:nil
                                                                     message:NSLocalizedStringFromTable(@"settings_add_3pid_invalid_password_message", @"Vector", nil)
                                                              preferredStyle:UIAlertControllerStyleAlert];

            [self->currentAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"retry", @"Vector", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                self->currentAlert = nil;

                [self requestAccountPasswordWithTitle:NSLocalizedStringFromTable(@"settings_add_3pid_password_title_email", @"Vector", nil)
                                              message:NSLocalizedStringFromTable(@"settings_add_3pid_password_message", @"Vector", nil)
                                           onComplete:^(NSString *password) {
                    [self tryFinaliseAddEmailSession:threePidAddSession withPassword:password threePidAddManager:threePidAddManager];
                }];
            }]];

            [self presentViewController:self->currentAlert animated:YES completion:nil];

            return;
        }

        self->is3PIDBindingInProgress = NO;

        // Check whether destroy has been called during email binding
        if (self->onReadyToDestroyHandler)
        {
            // Ready to destroy
            self->onReadyToDestroyHandler();
            self->onReadyToDestroyHandler = nil;
        }
        else
        {
            self->currentAlert = nil;

            // Display the same popup again if the error is M_THREEPID_AUTH_FAILED
            MXError *mxError = [[MXError alloc] initWithNSError:error];
            if (mxError && [mxError.errcode isEqualToString:kMXErrCodeStringThreePIDAuthFailed])
            {
                [self showValidationEmailDialogWithMessage:[NSBundle mxk_localizedStringForKey:@"account_email_validation_error"]
                                         for3PidAddSession:threePidAddSession
                                        threePidAddManager:threePidAddManager
                                                  password:password];
            }
            else
            {
                [self stopActivityIndicator];

                // Notify user
                NSString *myUserId = self.mainSession.myUser.userId; // TODO: Hanlde multi-account
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];
            }
        }
    }];
}

- (void)showValidationMsisdnDialogWithMessage:(NSString*)message for3PidAddSession:(MX3PidAddSession*)threePidAddSession threePidAddManager:(MX3PidAddManager*)threePidAddManager password:(NSString*)password
{
    MXWeakify(self);
    
    [currentAlert dismissViewControllerAnimated:NO completion:nil];
    currentAlert = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"account_msisdn_validation_title"] message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        MXStrongifyAndReturnIfNil(self);

        self->currentAlert = nil;

        [self stopActivityIndicator];

        // Reset new phone adding
        self.newPhoneEditingEnabled = NO;
    }]];

    [currentAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.secureTextEntry = NO;
        textField.placeholder = nil;
        textField.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    
    [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"submit"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {

        MXStrongifyAndReturnIfNil(self);

        NSString *smsCode = [self->currentAlert textFields].firstObject.text;

        self->currentAlert = nil;

        if (smsCode.length)
        {
            [self finaliseAddPhoneNumberSession:threePidAddSession withToken:smsCode andPassword:password message:message threePidAddManager:threePidAddManager];
        }
        else
        {
            // Ask again the sms token
            [self showValidationMsisdnDialogWithMessage:message for3PidAddSession:threePidAddSession threePidAddManager:threePidAddManager password:password];
        }
    }]];
    
    [currentAlert mxk_setAccessibilityIdentifier: @"SettingsVCMsisdnValidationAlert"];
    [self presentViewController:currentAlert animated:YES completion:nil];
}

- (void)finaliseAddPhoneNumberSession:(MX3PidAddSession*)threePidAddSession withToken:(NSString*)token andPassword:(NSString*)password message:(NSString*)message threePidAddManager:(MX3PidAddManager*)threePidAddManager
{
    self->is3PIDBindingInProgress = YES;

    [threePidAddManager finaliseAddPhoneNumberSession:threePidAddSession withToken:token password:password success:^{

        self->is3PIDBindingInProgress = NO;

        // Check whether destroy has been called during the binding
        if (self->onReadyToDestroyHandler)
        {
            // Ready to destroy
            self->onReadyToDestroyHandler();
            self->onReadyToDestroyHandler = nil;
        }
        else
        {
            [self stopActivityIndicator];

            // Reset new phone adding
            self.newPhoneEditingEnabled = NO;

            // Update linked 3pids
            [self loadAccount3PIDs];
        }

    } failure:^(NSError * _Nonnull error) {

        NSLog(@"[SettingsViewController] finaliseAddPhoneNumberSession: Failed to submit the sms token");
   
        MXError *mxError = [[MXError alloc] initWithNSError:error];
        if (mxError && [mxError.errcode isEqualToString:kMXErrCodeStringForbidden])
        {
            NSLog(@"[SettingsViewController] finaliseAddPhoneNumberSession: Wrong password");

            // Ask password again
            self->currentAlert = [UIAlertController alertControllerWithTitle:nil
                                                                     message:NSLocalizedStringFromTable(@"settings_add_3pid_invalid_password_message", @"Vector", nil)
                                                              preferredStyle:UIAlertControllerStyleAlert];

            [self->currentAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"retry", @"Vector", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                self->currentAlert = nil;

                [self requestAccountPasswordWithTitle:NSLocalizedStringFromTable(@"settings_add_3pid_password_title_msidsn", @"Vector", nil)
                                              message:NSLocalizedStringFromTable(@"settings_add_3pid_password_message", @"Vector", nil)
                                           onComplete:^(NSString *password) {
                                               [self finaliseAddPhoneNumberSession:threePidAddSession withToken:token andPassword:password message:message threePidAddManager:threePidAddManager];
                }];
            }]];

            [self presentViewController:self->currentAlert animated:YES completion:nil];

            return;
        }

        self->is3PIDBindingInProgress = NO;

        // Check whether destroy has been called during phone binding
        if (self->onReadyToDestroyHandler)
        {
            // Ready to destroy
            self->onReadyToDestroyHandler();
            self->onReadyToDestroyHandler = nil;
        }
        else
        {
            // Ignore connection cancellation error
            if (([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled))
            {
                [self stopActivityIndicator];
                return;
            }

            // Alert user
            NSString *title = [error.userInfo valueForKey:NSLocalizedFailureReasonErrorKey];
            NSString *msg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
            if (!title)
            {
                if (msg)
                {
                    title = msg;
                    msg = nil;
                }
                else
                {
                    title = [NSBundle mxk_localizedStringForKey:@"error"];
                }
            }


            self->currentAlert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];

            [self->currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                self->currentAlert = nil;

                // Ask again the sms token
                [self showValidationMsisdnDialogWithMessage:message for3PidAddSession:threePidAddSession threePidAddManager:threePidAddManager password:password];
            }]];

            [self->currentAlert mxk_setAccessibilityIdentifier: @"SettingsVCErrorAlert"];
            [self presentViewController:self->currentAlert animated:YES completion:nil];
        }
    }];
}

- (void)loadAccount3PIDs
{
    // Refresh the account 3PIDs list
    MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;
    [account load3PIDs:^{

        NSArray<MXThirdPartyIdentifier*> *thirdPartyIdentifiers = account.threePIDs ?: @[];
        [self.settingsDiscoveryViewModel updateWithThirdPartyIdentifiers:thirdPartyIdentifiers];
        
        // Refresh all the table (A slide down animation is observed when we limit the refresh to the concerned section).
        // Note: The use of 'reloadData' handles the case where the account has been logged out.
        [self refreshSettings];

    } failure:^(NSError *error) {
        
        // Display the data that has been loaded last time
        // Note: The use of 'reloadData' handles the case where the account has been logged out.
        [self refreshSettings];
        
    }];
}

- (void)editNewEmailTextField
{
    if (newEmailTextField && ![newEmailTextField becomeFirstResponder])
    {
        // Retry asynchronously
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self editNewEmailTextField];
            
        });
    }
}

- (void)editNewPhoneNumberTextField
{
    if (newPhoneNumberCell && ![newPhoneNumberCell.mxkTextField becomeFirstResponder])
    {
        // Retry asynchronously
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self editNewPhoneNumberTextField];
            
        });
    }
}

- (void)refreshSettings
{
    // Check whether a text input is currently edited
    keepNewEmailEditing = newEmailTextField ? newEmailTextField.isFirstResponder : NO;
    keepNewPhoneNumberEditing = newPhoneNumberCell ? newPhoneNumberCell.mxkTextField.isFirstResponder : NO;
    
    // Trigger a full table reloadData
    [self updateSections];
    
    // Restore the previous edited field
    if (keepNewEmailEditing)
    {
        [self editNewEmailTextField];
        keepNewEmailEditing = NO;
    }
    else if (keepNewPhoneNumberEditing)
    {
        [self editNewPhoneNumberTextField];
        keepNewPhoneNumberEditing = NO;
    }
}

- (void)formatNewPhoneNumber
{
    if (newPhoneNumber)
    {
        NSString *formattedNumber = [[NBPhoneNumberUtil sharedInstance] format:newPhoneNumber numberFormat:NBEPhoneNumberFormatINTERNATIONAL error:nil];
        NSString *prefix = newPhoneNumberCell.mxkLabel.text;
        if ([formattedNumber hasPrefix:prefix])
        {
            // Format the display phone number
            newPhoneNumberCell.mxkTextField.text = [formattedNumber substringFromIndex:prefix.length];
        }
    }
}

- (void)setupDiscoverySection
{
    MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;
    
    NSArray<MXThirdPartyIdentifier*> *thirdPartyIdentifiers = account.threePIDs ?: @[];
    
    SettingsDiscoveryViewModel *viewModel = [[SettingsDiscoveryViewModel alloc] initWithSession:self.mainSession thirdPartyIdentifiers:thirdPartyIdentifiers];
    viewModel.coordinatorDelegate = self;
    
    SettingsDiscoveryTableViewSection *discoverySection = [[SettingsDiscoveryTableViewSection alloc] initWithViewModel:viewModel];
    discoverySection.delegate = self;
    
    self.settingsDiscoveryViewModel = viewModel;
    self.settingsDiscoveryTableViewSection = discoverySection;
}

#pragma mark - 3Pid Add

-(void)checkAuthenticationFlowForAdding:(MX3PIDMedium)medium withSession:(MXSession*)session onComplete:(void (^)(NSString *password))onComplete
{
    [self startActivityIndicator];

    [session.threePidAddManager authenticationFlowForAdd3PidWithSuccess:^(NSArray<MXLoginFlow *> * _Nullable flows) {
        [self stopActivityIndicator];

        if (flows)
        {
            // We support only "m.login.password"
            BOOL hasPasswordFlow = NO;
            for (MXLoginFlow *flow in flows)
            {
                if ([flow.stages containsObject:kMXLoginFlowTypePassword])
                {
                    hasPasswordFlow = YES;
                    break;
                }
            }

            if (hasPasswordFlow)
            {
                // Ask password to the user while we are here
                NSString *title = NSLocalizedStringFromTable(@"settings_add_3pid_password_title_email", @"Vector", nil);
                if ([medium isEqualToString:kMX3PIDMediumMSISDN])
                {
                    title = NSLocalizedStringFromTable(@"settings_add_3pid_password_title_msidsn", @"Vector", nil);
                }

                [self requestAccountPasswordWithTitle:title
                                              message:NSLocalizedStringFromTable(@"settings_add_3pid_password_message", @"Vector", nil)
                                           onComplete:onComplete];
            }
            else
            {
                // The user needs to use Riot-web
                NSString *appName = [[NSBundle mainBundle] infoDictionary][@"CFBundleDisplayName"];
                NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"error_not_supported_on_mobile", @"Vector", nil), appName];
                [[AppDelegate theDelegate] showAlertWithTitle:nil message:message];
            }
        }
        else
        {
            // No auth
            onComplete(nil);
        }

    } failure:^(NSError * _Nonnull error) {
        [self stopActivityIndicator];
        [[AppDelegate theDelegate] showErrorAsAlert:error];
    }];
}

- (void)requestAccountPasswordWithTitle:(NSString*)title message:(NSString*)message onComplete:(void (^)(NSString *password))onComplete
{
    [currentAlert dismissViewControllerAnimated:NO completion:nil];

    // Prompt the user before deleting the device.
    currentAlert = [UIAlertController alertControllerWithTitle:title
                                                       message:message
                                                preferredStyle:UIAlertControllerStyleAlert];

    [currentAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.secureTextEntry = YES;
        textField.placeholder = nil;
        textField.keyboardType = UIKeyboardTypeDefault;
    }];

    MXWeakify(self);
    [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action)
                             {
                                 MXStrongifyAndReturnIfNil(self);
                                 self->currentAlert = nil;
                             }]];

    [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"continue"]
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       MXStrongifyAndReturnIfNil(self);

                                                       UITextField *textField = [self->currentAlert textFields].firstObject;
                                                       self->currentAlert = nil;

                                                       onComplete(textField.text);
                                                   }]];

    [self presentViewController:currentAlert animated:YES completion:nil];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Keep ref on destinationViewController
    [super prepareForSegue:segue sender:sender];
    
    // FIXME add night mode
}

#pragma mark - UITableView data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // update the save button if there is an update
    [self updateSaveButtonStatus];
    
    return _sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    Section *sectionObject = nil;
    if (section < _sections.count)
    {
        sectionObject = _sections[section];
    }
    return sectionObject.rows.count;
}

- (MXKTableViewCellWithLabelAndTextField*)getLabelAndTextFieldCell:(UITableView*)tableview forIndexPath:(NSIndexPath *)indexPath
{
    MXKTableViewCellWithLabelAndTextField *cell = [tableview dequeueReusableCellWithIdentifier:[MXKTableViewCellWithLabelAndTextField defaultReuseIdentifier] forIndexPath:indexPath];
    
    cell.mxkLabelLeadingConstraint.constant = cell.vc_separatorInset.left;
    cell.mxkTextFieldLeadingConstraint.constant = 16;
    cell.mxkTextFieldTrailingConstraint.constant = 15;
    
    cell.mxkLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
    
    cell.mxkTextField.userInteractionEnabled = YES;
    cell.mxkTextField.borderStyle = UITextBorderStyleNone;
    cell.mxkTextField.textAlignment = NSTextAlignmentRight;
    cell.mxkTextField.textColor = ThemeService.shared.theme.textSecondaryColor;
    cell.mxkTextField.font = [UIFont systemFontOfSize:16];
    cell.mxkTextField.placeholder = nil;
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    
    cell.alpha = 1.0f;
    cell.userInteractionEnabled = YES;
    
    [cell layoutIfNeeded];
    
    return cell;
}

- (MXKTableViewCellWithLabelAndSwitch*)getLabelAndSwitchCell:(UITableView*)tableview forIndexPath:(NSIndexPath *)indexPath
{
    MXKTableViewCellWithLabelAndSwitch *cell = [tableview dequeueReusableCellWithIdentifier:[MXKTableViewCellWithLabelAndSwitch defaultReuseIdentifier] forIndexPath:indexPath];
    
    cell.mxkLabelLeadingConstraint.constant = cell.vc_separatorInset.left;
    cell.mxkSwitchTrailingConstraint.constant = 15;
    
    cell.mxkLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
    
    [cell.mxkSwitch removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
    
    // Force layout before reusing a cell (fix switch displayed outside the screen)
    [cell layoutIfNeeded];
    
    return cell;
}

- (MXKTableViewCell*)getDefaultTableViewCell:(UITableView*)tableView
{
    MXKTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCell defaultReuseIdentifier]];
    if (!cell)
    {
        cell = [[MXKTableViewCell alloc] init];
    }
    else
    {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.accessoryView = nil;
    }
    cell.textLabel.accessibilityIdentifier = nil;
    cell.textLabel.font = [UIFont systemFontOfSize:17];
    cell.textLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
    cell.contentView.backgroundColor = UIColor.clearColor;
    
    return cell;
}

- (MXKTableViewCellWithTextView*)textViewCellForTableView:(UITableView*)tableView atIndexPath:(NSIndexPath *)indexPath
{
    MXKTableViewCellWithTextView *textViewCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithTextView defaultReuseIdentifier] forIndexPath:indexPath];
    
    textViewCell.mxkTextView.textColor = ThemeService.shared.theme.textPrimaryColor;
    textViewCell.mxkTextView.font = [UIFont systemFontOfSize:17];
    textViewCell.mxkTextView.backgroundColor = [UIColor clearColor];
    textViewCell.mxkTextViewLeadingConstraint.constant = tableView.vc_separatorInset.left;
    textViewCell.mxkTextViewTrailingConstraint.constant = tableView.vc_separatorInset.right;
    textViewCell.mxkTextView.accessibilityIdentifier = nil;
    
    return textViewCell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    Section *sectionObj = nil;
    NSInteger section = NSNotFound;
    NSInteger row = NSNotFound;
    
    if (indexPath.section < _sections.count)
    {
        sectionObj = _sections[indexPath.section];
        section = sectionObj.tag;
        if (indexPath.row < sectionObj.rows.count)
        {
            row = sectionObj.rows[indexPath.row].tag;
        }
    }

    // set the cell to a default value to avoid application crashes
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.backgroundColor = [UIColor redColor];
    
    // check if there is a valid session
    if (([AppDelegate theDelegate].mxSessions.count == 0) || ([MXKAccountManager sharedManager].activeAccounts.count == 0))
    {
        // else use a default cell
        return cell;
    }
    
    MXSession* session = [AppDelegate theDelegate].mxSessions[0];
    MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;

    if (section == SECTION_TAG_SIGN_OUT)
    {
        MXKTableViewCellWithButton *signOutCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier]];
        if (!signOutCell)
        {
            signOutCell = [[MXKTableViewCellWithButton alloc] init];
        }
        else
        {
            // Fix https://github.com/vector-im/riot-ios/issues/1354
            // Do not move this line in prepareForReuse because of https://github.com/vector-im/riot-ios/issues/1323
            signOutCell.mxkButton.titleLabel.text = nil;
        }
        
        NSString* title = NSLocalizedStringFromTable(@"settings_sign_out", @"Vector", nil);
        
        [signOutCell.mxkButton setTitle:title forState:UIControlStateNormal];
        [signOutCell.mxkButton setTitle:title forState:UIControlStateHighlighted];
        [signOutCell.mxkButton setTintColor:ThemeService.shared.theme.tintColor];
        signOutCell.mxkButton.titleLabel.font = [UIFont systemFontOfSize:17];
        
        [signOutCell.mxkButton  removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
        [signOutCell.mxkButton addTarget:self action:@selector(onSignout:) forControlEvents:UIControlEventTouchUpInside];
        signOutCell.mxkButton.accessibilityIdentifier=@"SettingsVCSignOutButton";
        
        cell = signOutCell;
    }
    else if (section == SECTION_TAG_USER_SETTINGS)
    {
        MXMyUser* myUser = session.myUser;
        
        if (row == USER_SETTINGS_PROFILE_PICTURE_INDEX)
        {
            MXKTableViewCellWithLabelAndMXKImageView *profileCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithLabelAndMXKImageView defaultReuseIdentifier] forIndexPath:indexPath];
            
            profileCell.mxkLabelLeadingConstraint.constant = profileCell.vc_separatorInset.left;
            profileCell.mxkImageViewTrailingConstraint.constant = 10;
            
            profileCell.mxkImageViewWidthConstraint.constant = profileCell.mxkImageViewHeightConstraint.constant = 30;
            profileCell.mxkImageViewDisplayBoxType = MXKTableViewCellDisplayBoxTypeCircle;
            
            if (!profileCell.mxkImageView.gestureRecognizers.count)
            {
                // tap on avatar to update it
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onProfileAvatarTap:)];
                [profileCell.mxkImageView addGestureRecognizer:tap];
            }
            
            profileCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_profile_picture", @"Vector", nil);
            profileCell.accessibilityIdentifier=@"SettingsVCProfilPictureStaticText";
            profileCell.mxkLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
            
            // if the user defines a new avatar
            if (newAvatarImage)
            {
                profileCell.mxkImageView.image = newAvatarImage;
            }
            else
            {
                UIImage* avatarImage = [AvatarGenerator generateAvatarForMatrixItem:myUser.userId withDisplayName:myUser.displayname];
                
                if (myUser.avatarUrl)
                {
                    profileCell.mxkImageView.enableInMemoryCache = YES;
                    
                    [profileCell.mxkImageView setImageURI:myUser.avatarUrl
                                                 withType:nil
                                      andImageOrientation:UIImageOrientationUp
                                            toFitViewSize:profileCell.mxkImageView.frame.size
                                               withMethod:MXThumbnailingMethodCrop
                                             previewImage:avatarImage
                                             mediaManager:session.mediaManager];
                }
                else
                {
                    profileCell.mxkImageView.image = avatarImage;
                }
            }
            
            cell = profileCell;
        }
        else if (row == USER_SETTINGS_DISPLAYNAME_INDEX)
        {
            MXKTableViewCellWithLabelAndTextField *displaynameCell = [self getLabelAndTextFieldCell:tableView forIndexPath:indexPath];
            
            displaynameCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_display_name", @"Vector", nil);
            displaynameCell.mxkTextField.text = myUser.displayname;
            
            displaynameCell.mxkTextField.tag = row;
            displaynameCell.mxkTextField.delegate = self;
            [displaynameCell.mxkTextField removeTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
            [displaynameCell.mxkTextField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
            displaynameCell.mxkTextField.accessibilityIdentifier=@"SettingsVCDisplayNameTextField";
            
            cell = displaynameCell;
        }
        else if (row == USER_SETTINGS_FIRST_NAME_INDEX)
        {
            MXKTableViewCellWithLabelAndTextField *firstCell = [self getLabelAndTextFieldCell:tableView forIndexPath:indexPath];
        
            firstCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_first_name", @"Vector", nil);
            firstCell.mxkTextField.userInteractionEnabled = NO;
            
            cell = firstCell;
        }
        else if (row == USER_SETTINGS_SURNAME_INDEX)
        {
            MXKTableViewCellWithLabelAndTextField *surnameCell = [self getLabelAndTextFieldCell:tableView forIndexPath:indexPath];
            
            surnameCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_surname", @"Vector", nil);
            surnameCell.mxkTextField.userInteractionEnabled = NO;
            
            cell = surnameCell;
        }
        else if (row >= USER_SETTINGS_EMAILS_OFFSET)
        {
            NSInteger emailIndex = row - USER_SETTINGS_EMAILS_OFFSET;
            MXKTableViewCellWithLabelAndTextField *emailCell = [self getLabelAndTextFieldCell:tableView forIndexPath:indexPath];
            
            emailCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_email_address", @"Vector", nil);
            emailCell.mxkTextField.text = account.linkedEmails[emailIndex];
            emailCell.mxkTextField.userInteractionEnabled = NO;
            
            cell = emailCell;
        }
        else if (row >= USER_SETTINGS_PHONENUMBERS_OFFSET)
        {
            NSInteger phoneNumberIndex = row - USER_SETTINGS_PHONENUMBERS_OFFSET;
            MXKTableViewCellWithLabelAndTextField *phoneCell = [self getLabelAndTextFieldCell:tableView forIndexPath:indexPath];
            
            phoneCell.mxkLabel.text = NSLocalizedStringFromTable(@"settings_phone_number", @"Vector", nil);
            
            phoneCell.mxkTextField.text = [MXKTools readableMSISDN:account.linkedPhoneNumbers[phoneNumberIndex]];
            phoneCell.mxkTextField.userInteractionEnabled = NO;
            
            cell = phoneCell;
        }
    }
  else if (section == SECTION_TAG_USER_INTERFACE)
  {
      if (row == USER_INTERFACE_LANGUAGE_INDEX)
      {
          cell = [tableView dequeueReusableCellWithIdentifier:kSettingsViewControllerPhoneBookCountryCellId];
          if (!cell)
          {
              cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kSettingsViewControllerPhoneBookCountryCellId];
          }

          NSString *language = [NSBundle mxk_language];
          if (!language)
          {
              language = [MXKLanguagePickerViewController defaultLanguage];
          }
          NSString *languageDescription = [MXKLanguagePickerViewController languageDescription:language];

          // Capitalise the description in the language locale
          NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:language];
          languageDescription = [languageDescription capitalizedStringWithLocale:locale];

          cell.textLabel.textColor = ThemeService.shared.theme.textPrimaryColor;

          cell.textLabel.text = NSLocalizedStringFromTable(@"settings_ui_language", @"Vector", nil);
          cell.detailTextLabel.text = languageDescription;

          [cell vc_setAccessoryDisclosureIndicatorWithCurrentTheme];
          cell.selectionStyle = UITableViewCellSelectionStyleDefault;
      }
      else if (row == USER_INTERFACE_THEME_INDEX)
      {
          cell = [tableView dequeueReusableCellWithIdentifier:kSettingsViewControllerPhoneBookCountryCellId];
          if (!cell)
          {
              cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kSettingsViewControllerPhoneBookCountryCellId];
          }

          NSString *theme = RiotSettings.shared.userInterfaceTheme;
          
          if (!theme)
          {
              if (@available(iOS 11.0, *))
              {
                  // "auto" is used the default value from iOS 11
                  theme = @"auto";
              }
              else
              {
                  // Use "light" for older version
                  theme = @"light";
              }
          }

          theme = [NSString stringWithFormat:@"settings_ui_theme_%@", theme];
          NSString *i18nTheme = NSLocalizedStringFromTable(theme,
                                                            @"Vector",
                                                           nil);

          cell.textLabel.textColor = ThemeService.shared.theme.textPrimaryColor;

          cell.textLabel.text = NSLocalizedStringFromTable(@"settings_ui_theme", @"Vector", nil);
          cell.detailTextLabel.text = i18nTheme;

          [cell vc_setAccessoryDisclosureIndicatorWithCurrentTheme];
          cell.selectionStyle = UITableViewCellSelectionStyleDefault;
      }
    }
    else if (section == SECTION_TAG_IGNORED_USERS)
    {
        MXKTableViewCell *ignoredUserCell = [self getDefaultTableViewCell:tableView];

        ignoredUserCell.textLabel.text = session.ignoredUsers[row];

        cell = ignoredUserCell;
    }
    else if (section == SECTION_TAG_FLAIR)
    {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:groupsDataSource.joinedGroupsSection];
        cell = [groupsDataSource tableView:tableView cellForRowAtIndexPath:indexPath];
        
        if ([cell isKindOfClass:GroupTableViewCellWithSwitch.class])
        {
            GroupTableViewCellWithSwitch* groupWithSwitchCell = (GroupTableViewCellWithSwitch*)cell;
            id<MXKGroupCellDataStoring> groupCellData = [groupsDataSource cellDataAtIndex:indexPath];
            
            // Display the groupId in the description label, except if the group has no name
            if (![groupWithSwitchCell.groupName.text isEqualToString:groupCellData.group.groupId])
            {
                groupWithSwitchCell.groupDescription.hidden = NO;
                groupWithSwitchCell.groupDescription.text = groupCellData.group.groupId;
            }
            
            // Update the toogle button
            groupWithSwitchCell.toggleButton.on = groupCellData.group.summary.user.isPublicised;
            groupWithSwitchCell.toggleButton.enabled = YES;
            groupWithSwitchCell.toggleButton.tag = row;
            
            [groupWithSwitchCell.toggleButton removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
            [groupWithSwitchCell.toggleButton addTarget:self action:@selector(toggleCommunityFlair:) forControlEvents:UIControlEventTouchUpInside];
        }
    }
    else if (section == SECTION_TAG_SECURITY)
    {
        switch (row)
        {
            case SECURITY_BUTTON_INDEX:
                cell = [self getDefaultTableViewCell:tableView];
                cell.textLabel.text = NSLocalizedStringFromTable(@"security_settings_title", @"Vector", nil);
                [cell vc_setAccessoryDisclosureIndicatorWithCurrentTheme];
                break;
        }
    }
    else if (section == SECTION_TAG_DEACTIVATE_ACCOUNT)
    {
        MXKTableViewCellWithButton *deactivateAccountBtnCell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier]];
        
        if (!deactivateAccountBtnCell)
        {
            deactivateAccountBtnCell = [[MXKTableViewCellWithButton alloc] init];
        }
        else
        {
            // Fix https://github.com/vector-im/riot-ios/issues/1354
            deactivateAccountBtnCell.mxkButton.titleLabel.text = nil;
        }
        
        NSString *btnTitle = NSLocalizedStringFromTable(@"settings_deactivate_my_account", @"Vector", nil);
        [deactivateAccountBtnCell.mxkButton setTitle:btnTitle forState:UIControlStateNormal];
        [deactivateAccountBtnCell.mxkButton setTitle:btnTitle forState:UIControlStateHighlighted];
        [deactivateAccountBtnCell.mxkButton setTintColor:ThemeService.shared.theme.warningColor];
        deactivateAccountBtnCell.mxkButton.titleLabel.font = [UIFont systemFontOfSize:17];
        
        [deactivateAccountBtnCell.mxkButton removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
        [deactivateAccountBtnCell.mxkButton addTarget:self action:@selector(deactivateAccountAction) forControlEvents:UIControlEventTouchUpInside];
        deactivateAccountBtnCell.mxkButton.accessibilityIdentifier = nil;
        
        cell = deactivateAccountBtnCell;
    }

    return cell;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    Section *sectionObj = nil;
    if (section < _sections.count)
    {
        sectionObj = _sections[section];
    }
    return sectionObj.headerTitle;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if ([view isKindOfClass:UITableViewHeaderFooterView.class])
    {
        // Customize label style
        UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView*)view;
        tableViewHeaderFooterView.textLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
        tableViewHeaderFooterView.textLabel.font = [UIFont systemFontOfSize:15];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    Section *sectionObj = nil;
    NSInteger section = NSNotFound;
    NSInteger row = NSNotFound;
    
    if (indexPath.section < _sections.count)
    {
        sectionObj = _sections[indexPath.section];
        section = sectionObj.tag;
        if (indexPath.row < sectionObj.rows.count)
        {
            row = sectionObj.rows[indexPath.row].tag;
        }
    }
    
    if (section == SECTION_TAG_USER_SETTINGS)
    {
        return row >= USER_SETTINGS_PHONENUMBERS_OFFSET;
    }
    return NO;
}

- (void)tableView:(UITableView*)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath*)indexPath
{
    // iOS8 requires this method to enable editing (see editActionsForRowAtIndexPath).
}

#pragma mark - UITableView delegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
{
    cell.backgroundColor = ThemeService.shared.theme.backgroundColor;
    
    if (cell.selectionStyle != UITableViewCellSelectionStyleNone)
    {        
        // Update the selected background view
        if (ThemeService.shared.theme.selectedBackgroundColor)
        {
            cell.selectedBackgroundView = [[UIView alloc] init];
            cell.selectedBackgroundView.backgroundColor = ThemeService.shared.theme.selectedBackgroundColor;
        }
        else
        {
            if (tableView.style == UITableViewStylePlain)
            {
                cell.selectedBackgroundView = nil;
            }
            else
            {
                cell.selectedBackgroundView.backgroundColor = nil;
            }
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 24;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 24;
}

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    Section *sectionObj = nil;
    NSInteger section = NSNotFound;
    NSInteger row = NSNotFound;
    
    if (indexPath.section < _sections.count)
    {
        sectionObj = _sections[indexPath.section];
        section = sectionObj.tag;
        if (indexPath.row < sectionObj.rows.count)
        {
            row = sectionObj.rows[indexPath.row].tag;
        }
    }
    
    NSMutableArray* actions;
    
    // Add the swipe to delete user's email or phone number
    if (section == SECTION_TAG_USER_SETTINGS)
    {
        if (row >= USER_SETTINGS_PHONENUMBERS_OFFSET)
        {
            actions = [[NSMutableArray alloc] init];
            
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            CGFloat cellHeight = cell ? cell.frame.size.height : 50;
            
            // Patch: Force the width of the button by adding whitespace characters into the title string.
            UITableViewRowAction *leaveAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"    "  handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
                
                [self onRemove3PID:indexPath];
                
            }];
            
            leaveAction.backgroundColor = [MXKTools convertImageToPatternColor:@"remove_icon_pink" backgroundColor:ThemeService.shared.theme.headerBackgroundColor patternSize:CGSizeMake(50, cellHeight) resourceSize:CGSizeMake(24, 24)];
            [actions insertObject:leaveAction atIndex:0];
        }
    }
    
    return actions;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.tableView == tableView)
    {
        Section *sectionObj = nil;
        NSInteger section = NSNotFound;
        NSInteger row = NSNotFound;
        
        if (indexPath.section < _sections.count)
        {
            sectionObj = _sections[indexPath.section];
            section = sectionObj.tag;
            if (indexPath.row < sectionObj.rows.count)
            {
                row = sectionObj.rows[indexPath.row].tag;
            }
        }

        if (section == SECTION_TAG_USER_INTERFACE)
        {
            if (row == USER_INTERFACE_LANGUAGE_INDEX)
            {
                // Display the language picker
                LanguagePickerViewController *languagePickerViewController = [LanguagePickerViewController languagePickerViewController];
                languagePickerViewController.selectedLanguage = [NSBundle mxk_language];
                languagePickerViewController.delegate = self;
                [self pushViewController:languagePickerViewController];
            }
            else if (row == USER_INTERFACE_THEME_INDEX)
            {
                [self showThemePicker];
            }
        }
        else if (section == SECTION_TAG_IGNORED_USERS)
        {
            MXSession* session = [AppDelegate theDelegate].mxSessions[0];

            NSString *ignoredUserId = session.ignoredUsers[row];

            if (ignoredUserId)
            {
                [currentAlert dismissViewControllerAnimated:NO completion:nil];

                __weak typeof(self) weakSelf = self;
                
                currentAlert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:NSLocalizedStringFromTable(@"settings_unignore_user", @"Vector", nil), ignoredUserId] message:nil preferredStyle:UIAlertControllerStyleAlert];

                [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"yes"]
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * action) {
                                                                   
                                                                   if (weakSelf)
                                                                   {
                                                                       typeof(self) self = weakSelf;
                                                                       self->currentAlert = nil;
                                                                       
                                                                       MXSession* session = [AppDelegate theDelegate].mxSessions[0];
                                                                       
                                                                       // Remove the member from the ignored user list
                                                                       [self startActivityIndicator];
                                                                       [session unIgnoreUsers:@[ignoredUserId] success:^{
                                                                           
                                                                           [self stopActivityIndicator];
                                                                           
                                                                       } failure:^(NSError *error) {
                                                                           
                                                                           [self stopActivityIndicator];
                                                                           
                                                                           NSLog(@"[SettingsViewController] Unignore %@ failed", ignoredUserId);
                                                                           
                                                                           NSString *myUserId = session.myUser.userId;
                                                                           [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];
                                                                           
                                                                       }];
                                                                   }
                                                                   
                                                               }]];
                
                [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"no"]
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * action) {
                                                                   
                                                                   if (weakSelf)
                                                                   {
                                                                       typeof(self) self = weakSelf;
                                                                       self->currentAlert = nil;
                                                                   }
                                                                   
                                                               }]];
                
                [currentAlert mxk_setAccessibilityIdentifier: @"SettingsVCUnignoreAlert"];
                [self presentViewController:currentAlert animated:YES completion:nil];
            }
        }
        else if (section == SECTION_TAG_USER_SETTINGS)
        {
            if (row == USER_SETTINGS_PROFILE_PICTURE_INDEX)
            {
                [self onProfileAvatarTap:nil];
            }
        }
        else if (section == SECTION_TAG_SECURITY)
        {
            switch (row)
            {
                case SECURITY_BUTTON_INDEX:
                {
                    SecurityViewController *securityViewController = [SecurityViewController instantiateWithMatrixSession:self.mainSession];

                    [self pushViewController:securityViewController];
                    break;
                }
            }
        }
        
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - actions


- (void)onSignout:(id)sender
{
    self.signOutButton = (UIButton*)sender;
    
    MXKeyBackup *keyBackup = self.mainSession.crypto.backup;
    
    [self.signOutAlertPresenter presentFor:keyBackup.state
                      areThereKeysToBackup:keyBackup.hasKeysToBackup
                                      from:self
                                sourceView:self.signOutButton
                                  animated:YES];
}

- (void)onRemove3PID:(NSIndexPath*)indexPath
{
    Section *sectionObj = nil;
    NSInteger section = NSNotFound;
    NSInteger row = NSNotFound;
    
    if (indexPath.section < _sections.count)
    {
        sectionObj = _sections[indexPath.section];
        section = sectionObj.tag;
        if (indexPath.row < sectionObj.rows.count)
        {
            row = sectionObj.rows[indexPath.row].tag;
        }
    }
    
    if (section == SECTION_TAG_USER_SETTINGS)
    {
        NSString *address, *medium;
        MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;
        NSString *promptMsg;
        
        if (row >= USER_SETTINGS_EMAILS_OFFSET)
        {
            medium = kMX3PIDMediumEmail;
            row = row - USER_SETTINGS_EMAILS_OFFSET;
            NSArray<NSString *> *linkedEmails = account.linkedEmails;
            if (row < linkedEmails.count)
            {
                address = linkedEmails[row];
                promptMsg = [NSString stringWithFormat:NSLocalizedStringFromTable(@"settings_remove_email_prompt_msg", @"Vector", nil), address];
            }
        }
        else if (row >= USER_SETTINGS_PHONENUMBERS_OFFSET)
        {
            medium = kMX3PIDMediumMSISDN;
            row = row - USER_SETTINGS_PHONENUMBERS_OFFSET;
            NSArray<NSString *> *linkedPhones = account.linkedPhoneNumbers;
            if (row < linkedPhones.count)
            {
                address = linkedPhones[row];
                NSString *e164 = [NSString stringWithFormat:@"+%@", address];
                NBPhoneNumber *phoneNb = [[NBPhoneNumberUtil sharedInstance] parse:e164 defaultRegion:nil error:nil];
                NSString *phoneMunber = [[NBPhoneNumberUtil sharedInstance] format:phoneNb numberFormat:NBEPhoneNumberFormatINTERNATIONAL error:nil];
                
                promptMsg = [NSString stringWithFormat:NSLocalizedStringFromTable(@"settings_remove_phone_prompt_msg", @"Vector", nil), phoneMunber];
            }
        }
        
        if (address && medium)
        {
            __weak typeof(self) weakSelf = self;
            
            if (currentAlert)
            {
                [currentAlert dismissViewControllerAnimated:NO completion:nil];
                currentAlert = nil;
            }
            
            // Remove ?
            currentAlert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"settings_remove_prompt_title", @"Vector", nil) message:promptMsg preferredStyle:UIAlertControllerStyleAlert];
            
            [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                             style:UIAlertActionStyleCancel
                                                           handler:^(UIAlertAction * action) {
                                                               
                                                               if (weakSelf)
                                                               {
                                                                   typeof(self) self = weakSelf;
                                                                   self->currentAlert = nil;
                                                               }
                                                               
                                                           }]];
            
            [currentAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"remove", @"Vector", nil)
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                               
                                                               if (weakSelf)
                                                               {
                                                                   typeof(self) self = weakSelf;
                                                                   self->currentAlert = nil;
                                                                   
                                                                   [self startActivityIndicator];
                                                                   
                                                                   [self.mainSession.matrixRestClient remove3PID:address medium:medium success:^{
                                                                       
                                                                       if (weakSelf)
                                                                       {
                                                                           typeof(self) self = weakSelf;
                                                                           
                                                                           [self stopActivityIndicator];
                                                                           
                                                                           // Update linked 3pids
                                                                           [self loadAccount3PIDs];
                                                                       }
                                                                       
                                                                   } failure:^(NSError *error) {
                                                                       
                                                                       NSLog(@"[SettingsViewController] Remove 3PID: %@ failed", address);
                                                                       if (weakSelf)
                                                                       {
                                                                           typeof(self) self = weakSelf;
                                                                           
                                                                           [self stopActivityIndicator];
                                                                           
                                                                           NSString *myUserId = self.mainSession.myUser.userId; // TODO: Hanlde multi-account
                                                                           [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];
                                                                       }
                                                                   }];
                                                               }
                                                               
                                                           }]];
            
            [currentAlert mxk_setAccessibilityIdentifier: @"SettingsVCRemove3PIDAlert"];
            [self presentViewController:currentAlert animated:YES completion:nil];
        }
    }
}

- (void)togglePushNotifications:(id)sender
{
    // Check first whether the user allow notification from device settings
    UIUserNotificationType currentUserNotificationTypes = UIApplication.sharedApplication.currentUserNotificationSettings.types;
    if (currentUserNotificationTypes == UIUserNotificationTypeNone)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        
        __weak typeof(self) weakSelf = self;

        NSString *appDisplayName = [[NSBundle mainBundle] infoDictionary][@"CFBundleDisplayName"];
        
        currentAlert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:NSLocalizedStringFromTable(@"settings_on_denied_notification", @"Vector", nil), appDisplayName] message:nil preferredStyle:UIAlertControllerStyleAlert];
        
        [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                           if (weakSelf)
                                                           {
                                                               typeof(self) self = weakSelf;
                                                               self->currentAlert = nil;
                                                           }
                                                           
                                                       }]];
        
        [currentAlert mxk_setAccessibilityIdentifier: @"SettingsVCPushNotificationsAlert"];
        [self presentViewController:currentAlert animated:YES completion:nil];
        
        // Keep off the switch
        ((UISwitch*)sender).on = NO;
    }
    else if ([MXKAccountManager sharedManager].activeAccounts.count)
    {
        [self startActivityIndicator];
        
        MXKAccountManager *accountManager = [MXKAccountManager sharedManager];
        MXKAccount* account = accountManager.activeAccounts.firstObject;

        if (accountManager.apnsDeviceToken)
        {
            [account enablePushNotifications:!account.pushNotificationServiceIsActive success:^{
                [self stopActivityIndicator];
            } failure:^(NSError *error) {
                [self stopActivityIndicator];
            }];
        }
        else
        {
            // Obtain device token when user has just enabled access to notifications from system settings
            [[AppDelegate theDelegate] registerForRemoteNotificationsWithCompletion:^(NSError * error) {
                if (error)
                {
                    [(UISwitch *)sender setOn:NO animated:YES];
                    [self stopActivityIndicator];
                }
                else
                {
                    [account enablePushNotifications:YES success:^{
                        [self stopActivityIndicator];
                    } failure:^(NSError *error) {
                        [self stopActivityIndicator];
                    }];
                }
            }];
        }
    }
}

- (void)toggleCallKit:(id)sender
{
    UISwitch *switchButton = (UISwitch*)sender;
    [MXKAppSettings standardAppSettings].enableCallKit = switchButton.isOn;
}

- (void)toggleStunServerFallback:(id)sender
{
    UISwitch *switchButton = (UISwitch*)sender;
    RiotSettings.shared.allowStunServerFallback = switchButton.isOn;

    self.mainSession.callManager.fallbackSTUNServer = RiotSettings.shared.allowStunServerFallback ? BuildSettings.stunServerFallbackUrlString : nil;
}

- (void)toggleAllowIntegrations:(id)sender
{
    UISwitch *switchButton = (UISwitch*)sender;

    MXSession *session = self.mainSession;
    [self startActivityIndicator];

    __block RiotSharedSettings *sharedSettings = [[RiotSharedSettings alloc] initWithSession:session];
    [sharedSettings setIntegrationProvisioningWithEnabled:switchButton.on success:^{
        sharedSettings = nil;
        [self stopActivityIndicator];
    } failure:^(NSError * _Nullable error) {
        sharedSettings = nil;
        [switchButton setOn:!switchButton.on animated:YES];
        [self stopActivityIndicator];
    }];
}

- (void)toggleShowDecodedContent:(id)sender
{
    UISwitch *switchButton = (UISwitch*)sender;
    RiotSettings.shared.showDecryptedContentInNotifications = switchButton.isOn;
}

- (void)toggleLocalContactsSync:(id)sender
{
    UISwitch *switchButton = (UISwitch*)sender;

    if (switchButton.on)
    {
        [MXKContactManager requestUserConfirmationForLocalContactsSyncInViewController:self completionHandler:^(BOOL granted) {

            [MXKAppSettings standardAppSettings].syncLocalContacts = granted;
            
            [self updateSections];
        }];
    }
    else
    {
        [MXKAppSettings standardAppSettings].syncLocalContacts = NO;
        
        [self updateSections];
    }
}

- (void)toggleSendCrashReport:(id)sender
{
    BOOL enable = RiotSettings.shared.enableCrashReport;
    if (enable)
    {
        NSLog(@"[SettingsViewController] disable automatic crash report and analytics sending");
        
        RiotSettings.shared.enableCrashReport = NO;
        
        [[Analytics sharedInstance] stop];
        
        // Remove potential crash file.
        [MXLogger deleteCrashLog];
    }
    else
    {
        NSLog(@"[SettingsViewController] enable automatic crash report and analytics sending");
        
        RiotSettings.shared.enableCrashReport = YES;
        
        [[Analytics sharedInstance] start];
    }
}

- (void)toggleEnableRageShake:(id)sender
{
    if (sender && [sender isKindOfClass:UISwitch.class])
    {
        UISwitch *switchButton = (UISwitch*)sender;

        RiotSettings.shared.enableRageShake = switchButton.isOn;

        [self updateSections];
    }
}

- (void)toggleJitsiForConference:(id)sender
{
    if (sender && [sender isKindOfClass:UISwitch.class])
    {
        UISwitch *switchButton = (UISwitch*)sender;
        
        RiotSettings.shared.createConferenceCallsWithJitsi = switchButton.isOn;

        [self.tableView reloadData];
    }
}

- (void)togglePinRoomsWithMissedNotif:(id)sender
{
    UISwitch *switchButton = (UISwitch*)sender;
    
    RiotSettings.shared.pinRoomsWithMissedNotificationsOnHome = switchButton.on;
}

- (void)togglePinRoomsWithUnread:(id)sender
{
    UISwitch *switchButton = (UISwitch*)sender;

    RiotSettings.shared.pinRoomsWithUnreadMessagesOnHome = switchButton.on;
}

- (void)toggleCommunityFlair:(id)sender
{
    UISwitch *switchButton = (UISwitch*)sender;
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:switchButton.tag inSection:groupsDataSource.joinedGroupsSection];
    id<MXKGroupCellDataStoring> groupCellData = [groupsDataSource cellDataAtIndex:indexPath];
    MXGroup *group = groupCellData.group;
    
    if (group)
    {
        [self startActivityIndicator];
        
        __weak typeof(self) weakSelf = self;
        
        [self.mainSession updateGroupPublicity:group isPublicised:switchButton.on success:^{
            
            if (weakSelf)
            {
                typeof(self) self = weakSelf;
                [self stopActivityIndicator];
            }
            
        } failure:^(NSError *error) {
            
            if (weakSelf)
            {
                typeof(self) self = weakSelf;
                [self stopActivityIndicator];
                
                // Come back to previous state button
                [switchButton setOn:!switchButton.isOn animated:YES];
                
                // Notify user
                [[AppDelegate theDelegate] showErrorAsAlert:error];
            }
        }];
    }
}

- (void)markAllAsRead:(id)sender
{
    // Feedback: disable button and run activity indicator
    UIButton *button = (UIButton*)sender;
    button.enabled = NO;
    [self startActivityIndicator];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        [[AppDelegate theDelegate] markAllMessagesAsRead];
        
        [self stopActivityIndicator];
        button.enabled = YES;
        
    });
}

- (void)clearCache:(id)sender
{
    // Feedback: disable button and run activity indicator
    UIButton *button = (UIButton*)sender;
    button.enabled = NO;

    [self launchClearCache];
}

- (void)launchClearCache
{
    [self startActivityIndicator];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{

        [[AppDelegate theDelegate] reloadMatrixSessions:YES];

    });
}

- (void)reportBug:(id)sender
{
    BugReportViewController *bugReportViewController = [BugReportViewController bugReportViewController];
    [bugReportViewController showInViewController:self];
}

- (void)selectPhoneNumberCountry:(id)sender
{
    newPhoneNumberCountryPicker = [CountryPickerViewController countryPickerViewController];
    newPhoneNumberCountryPicker.view.tag = SECTION_TAG_USER_SETTINGS;
    newPhoneNumberCountryPicker.delegate = self;
    newPhoneNumberCountryPicker.showCountryCallingCode = YES;
    [self pushViewController:newPhoneNumberCountryPicker];
}

//- (void)onRuleUpdate:(id)sender
//{
//    MXPushRule* pushRule = nil;
//    MXSession* session = [[AppDelegate theDelegate].mxSessions objectAtIndex:0];
//    
//    NSInteger row = ((UIView*)sender).tag;
//    
//    if (row == NOTIFICATION_SETTINGS_CONTAINING_MY_DISPLAY_NAME_INDEX)
//    {
//        pushRule = [session.notificationCenter ruleById:kMXNotificationCenterContainDisplayNameRuleID];
//    }
//    else if (row == NOTIFICATION_SETTINGS_CONTAINING_MY_USER_NAME_INDEX)
//    {
//        pushRule = [session.notificationCenter ruleById:kMXNotificationCenterContainUserNameRuleID];
//    }
//    else if (row == NOTIFICATION_SETTINGS_SENT_TO_ME_INDEX)
//    {
//        pushRule = [session.notificationCenter ruleById:kMXNotificationCenterOneToOneRoomRuleID];
//    }
//    else if (row == NOTIFICATION_SETTINGS_INVITED_TO_ROOM_INDEX)
//    {
//        pushRule = [session.notificationCenter ruleById:kMXNotificationCenterInviteMeRuleID];
//    }
//    else if (row == NOTIFICATION_SETTINGS_PEOPLE_LEAVE_JOIN_INDEX)
//    {
//        pushRule = [session.notificationCenter ruleById:kMXNotificationCenterMemberEventRuleID];
//    }
//    else if (row == NOTIFICATION_SETTINGS_CALL_INVITATION_INDEX)
//    {
//        pushRule = [session.notificationCenter ruleById:kMXNotificationCenterCallRuleID];
//    }
//    
//    if (pushRule)
//    {
//        // toggle the rule
//        [session.notificationCenter enableRule:pushRule isEnabled:!pushRule.enabled];
//    }
//}


- (void)onSave:(id)sender
{
    // sanity check
    if ([MXKAccountManager sharedManager].activeAccounts.count == 0)
    {
        return;
    }
    
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self startActivityIndicator];
    isSavingInProgress = YES;
    __weak typeof(self) weakSelf = self;
    
    MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;
    MXMyUser* myUser = account.mxSession.myUser;
    
    if (newDisplayName && ![myUser.displayname isEqualToString:newDisplayName])
    {
        // Save display name
        [account setUserDisplayName:newDisplayName success:^{
            
            if (weakSelf)
            {
                // Update the current displayname
                typeof(self) self = weakSelf;
                self->newDisplayName = nil;
                
                // Go to the next change saving step
                [self onSave:nil];
            }
            
        } failure:^(NSError *error) {
            
            NSLog(@"[SettingsViewController] Failed to set displayName");
            
            if (weakSelf)
            {
                typeof(self) self = weakSelf;
                [self handleErrorDuringProfileChangeSaving:error];
            }
            
        }];
        
        return;
    }
    
    if (newAvatarImage)
    {
        // Retrieve the current picture and make sure its orientation is up
        UIImage *updatedPicture = [MXKTools forceImageOrientationUp:newAvatarImage];
        
        // Upload picture
        MXMediaLoader *uploader = [MXMediaManager prepareUploaderWithMatrixSession:account.mxSession initialRange:0 andRange:1.0];
        
        [uploader uploadData:UIImageJPEGRepresentation(updatedPicture, 0.5) filename:nil mimeType:@"image/jpeg" success:^(NSString *url) {
            
            if (weakSelf)
            {
                typeof(self) self = weakSelf;
                
                // Store uploaded picture url and trigger picture saving
                self->uploadedAvatarURL = url;
                self->newAvatarImage = nil;
                [self onSave:nil];
            }
            
            
        } failure:^(NSError *error) {
            
            NSLog(@"[SettingsViewController] Failed to upload image");
            
            if (weakSelf)
            {
                typeof(self) self = weakSelf;
                [self handleErrorDuringProfileChangeSaving:error];
            }
            
        }];
        
        return;
    }
    else if (uploadedAvatarURL)
    {
        [account setUserAvatarUrl:uploadedAvatarURL
                             success:^{
                                 
                                 if (weakSelf)
                                 {
                                     typeof(self) self = weakSelf;
                                     self->uploadedAvatarURL = nil;
                                     [self onSave:nil];
                                 }
                                 
                             }
                             failure:^(NSError *error) {
                                 
                                 NSLog(@"[SettingsViewController] Failed to set avatar url");
                                
                                 if (weakSelf)
                                 {
                                     typeof(self) self = weakSelf;
                                     [self handleErrorDuringProfileChangeSaving:error];
                                 }
                                 
                             }];
        
        return;
    }
    
    // Backup is complete
    isSavingInProgress = NO;
    [self stopActivityIndicator];
    
    // Check whether destroy has been called durign saving
    if (onReadyToDestroyHandler)
    {
        // Ready to destroy
        onReadyToDestroyHandler();
        onReadyToDestroyHandler = nil;
    }
    else
    {
        [self updateSections];
    }
}

- (void)handleErrorDuringProfileChangeSaving:(NSError*)error
{
    // Sanity check: retrieve the current root view controller
    UIViewController *rootViewController = [AppDelegate theDelegate].window.rootViewController;
    if (rootViewController)
    {
        __weak typeof(self) weakSelf = self;
        
        // Alert user
        NSString *title = [error.userInfo valueForKey:NSLocalizedFailureReasonErrorKey];
        if (!title)
        {
            title = [NSBundle mxk_localizedStringForKey:@"settings_fail_to_update_profile"];
        }
        NSString *msg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
        
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        
        currentAlert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        
        [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                           if (weakSelf)
                                                           {
                                                               typeof(self) self = weakSelf;
                                                               
                                                               self->currentAlert = nil;
                                                               
                                                               // Reset the updated displayname
                                                               self->newDisplayName = nil;
                                                               
                                                               // Discard picture change
                                                               self->uploadedAvatarURL = nil;
                                                               self->newAvatarImage = nil;
                                                               
                                                               // Loop to end saving
                                                               [self onSave:nil];
                                                           }
                                                           
                                                       }]];
        
        [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"retry"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                           if (weakSelf)
                                                           {
                                                               typeof(self) self = weakSelf;
                                                               
                                                               self->currentAlert = nil;
                                                               
                                                               // Loop to retry saving
                                                               [self onSave:nil];
                                                           }
                                                           
                                                       }]];
        
        [currentAlert mxk_setAccessibilityIdentifier: @"SettingsVCSaveChangesFailedAlert"];
        [rootViewController presentViewController:currentAlert animated:YES completion:nil];
    }
}

- (IBAction)onAddNewEmail:(id)sender
{
    // Ignore empty field
    if (!newEmailTextField.text.length)
    {
        // Reset new email adding
        self.newEmailEditingEnabled = NO;
        return;
    }
    
    // Email check
    if (![MXTools isEmailAddress:newEmailTextField.text])
    {
         __weak typeof(self) weakSelf = self;
        
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        
        currentAlert = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"account_error_email_wrong_title"] message:[NSBundle mxk_localizedStringForKey:@"account_error_email_wrong_description"] preferredStyle:UIAlertControllerStyleAlert];
        
        [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                           if (weakSelf)
                                                           {
                                                               typeof(self) self = weakSelf;
                                                               
                                                               self->currentAlert = nil;
                                                           }
                                                           
                                                       }]];
        
        [currentAlert mxk_setAccessibilityIdentifier: @"SettingsVCAddEmailAlert"];
        [self presentViewController:currentAlert animated:YES completion:nil];

        return;
    }

    // Dismiss the keyboard
    [newEmailTextField resignFirstResponder];

    MXSession* session = [AppDelegate theDelegate].mxSessions[0];

    [self checkAuthenticationFlowForAdding:kMX3PIDMediumEmail withSession:session onComplete:^(NSString *password) {

        [self startActivityIndicator];

        __block MX3PidAddSession *thirdPidAddSession;
        thirdPidAddSession = [session.threePidAddManager startAddEmailSessionWithEmail:self->newEmailTextField.text nextLink:nil success:^{

            [self showValidationEmailDialogWithMessage:[NSBundle mxk_localizedStringForKey:@"account_email_validation_message"]
                                     for3PidAddSession:thirdPidAddSession
                                    threePidAddManager:session.threePidAddManager
                                              password:password];

        } failure:^(NSError * _Nonnull error) {

            [self stopActivityIndicator];

            NSLog(@"[SettingsViewController] Failed to request email token");

            // Translate the potential MX error.
            MXError *mxError = [[MXError alloc] initWithNSError:error];
            if (mxError
                && ([mxError.errcode isEqualToString:kMXErrCodeStringThreePIDInUse]
                    || [mxError.errcode isEqualToString:kMXErrCodeStringServerNotTrusted]))
            {
                NSMutableDictionary *userInfo;
                if (error.userInfo)
                {
                    userInfo = [NSMutableDictionary dictionaryWithDictionary:error.userInfo];
                }
                else
                {
                    userInfo = [NSMutableDictionary dictionary];
                }

                userInfo[NSLocalizedFailureReasonErrorKey] = nil;

                if ([mxError.errcode isEqualToString:kMXErrCodeStringThreePIDInUse])
                {
                    userInfo[NSLocalizedDescriptionKey] = NSLocalizedStringFromTable(@"auth_email_in_use", @"Vector", nil);
                    userInfo[@"error"] = NSLocalizedStringFromTable(@"auth_email_in_use", @"Vector", nil);
                }
                else
                {
                    userInfo[NSLocalizedDescriptionKey] = NSLocalizedStringFromTable(@"auth_untrusted_id_server", @"Vector", nil);
                    userInfo[@"error"] = NSLocalizedStringFromTable(@"auth_untrusted_id_server", @"Vector", nil);
                }

                error = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
            }
            else if ([error.domain isEqualToString:MX3PidAddManagerErrorDomain]
                     && error.code == MX3PidAddManagerErrorDomainIdentityServerRequired)
            {
                error = [NSError errorWithDomain:error.domain
                                            code:error.code
                                        userInfo:@{
                                                   NSLocalizedDescriptionKey: [NSBundle mxk_localizedStringForKey:@"auth_email_is_required"]
                                                   }];
            }

            // Notify user
            NSString *myUserId = session.myUser.userId; // TODO: Hanlde multi-account
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];

        }];
    }];
}

- (IBAction)onAddNewPhone:(id)sender
{
    // Ignore empty field
    if (!newPhoneNumberCell.mxkTextField.text.length)
    {
        // Disable the new phone edition if the text field is empty
        self.newPhoneEditingEnabled = NO;
        return;
    }

    // Phone check
    if (![[NBPhoneNumberUtil sharedInstance] isValidNumber:newPhoneNumber])
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        __weak typeof(self) weakSelf = self;

        currentAlert = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"account_error_msisdn_wrong_title"] message:[NSBundle mxk_localizedStringForKey:@"account_error_msisdn_wrong_description"] preferredStyle:UIAlertControllerStyleAlert];

        [currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {

                                                           if (weakSelf)
                                                           {
                                                               typeof(self) self = weakSelf;
                                                               self->currentAlert = nil;
                                                           }

                                                       }]];

        [currentAlert mxk_setAccessibilityIdentifier: @"SettingsVCAddMsisdnAlert"];
        [self presentViewController:currentAlert animated:YES completion:nil];

        return;
    }

    // Dismiss the keyboard
    [newPhoneNumberCell.mxkTextField resignFirstResponder];

    MXSession* session = [AppDelegate theDelegate].mxSessions[0];

    NSString *e164 = [[NBPhoneNumberUtil sharedInstance] format:newPhoneNumber numberFormat:NBEPhoneNumberFormatE164 error:nil];
    NSString *msisdn;
    if ([e164 hasPrefix:@"+"])
    {
        msisdn = e164;
    }
    else if ([e164 hasPrefix:@"00"])
    {
        msisdn = [NSString stringWithFormat:@"+%@", [e164 substringFromIndex:2]];
    }

    [self checkAuthenticationFlowForAdding:kMX3PIDMediumMSISDN withSession:session onComplete:^(NSString *password) {
        [self startActivityIndicator];

        __block MX3PidAddSession *new3Pid;
        new3Pid = [session.threePidAddManager startAddPhoneNumberSessionWithPhoneNumber:msisdn countryCode:nil success:^{

            [self showValidationMsisdnDialogWithMessage:[NSBundle mxk_localizedStringForKey:@"account_msisdn_validation_message"] for3PidAddSession:new3Pid threePidAddManager:session.threePidAddManager password:password];

        } failure:^(NSError *error) {

            [self stopActivityIndicator];

            NSLog(@"[SettingsViewController] Failed to request msisdn token");

            // Translate the potential MX error.
            MXError *mxError = [[MXError alloc] initWithNSError:error];
            if (mxError
                && ([mxError.errcode isEqualToString:kMXErrCodeStringThreePIDInUse]
                    || [mxError.errcode isEqualToString:kMXErrCodeStringServerNotTrusted]))
            {
                NSMutableDictionary *userInfo;
                if (error.userInfo)
                {
                    userInfo = [NSMutableDictionary dictionaryWithDictionary:error.userInfo];
                }
                else
                {
                    userInfo = [NSMutableDictionary dictionary];
                }

                userInfo[NSLocalizedFailureReasonErrorKey] = nil;

                if ([mxError.errcode isEqualToString:kMXErrCodeStringThreePIDInUse])
                {
                    userInfo[NSLocalizedDescriptionKey] = NSLocalizedStringFromTable(@"auth_phone_in_use", @"Vector", nil);
                    userInfo[@"error"] = NSLocalizedStringFromTable(@"auth_phone_in_use", @"Vector", nil);
                }
                else
                {
                    userInfo[NSLocalizedDescriptionKey] = NSLocalizedStringFromTable(@"auth_untrusted_id_server", @"Vector", nil);
                    userInfo[@"error"] = NSLocalizedStringFromTable(@"auth_untrusted_id_server", @"Vector", nil);
                }

                error = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
            }
            else if ([error.domain isEqualToString:MX3PidAddManagerErrorDomain]
                     && error.code == MX3PidAddManagerErrorDomainIdentityServerRequired)
            {
                error = [NSError errorWithDomain:error.domain
                                            code:error.code
                                        userInfo:@{
                                                   NSLocalizedDescriptionKey: [NSBundle mxk_localizedStringForKey:@"auth_phone_is_required"]
                                                   }];
            }

            // Notify user
            NSString *myUserId = session.myUser.userId;
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];
        }];
    }];
}

- (void)updateSaveButtonStatus
{
    if ([AppDelegate theDelegate].mxSessions.count > 0)
    {
        MXSession* session = [AppDelegate theDelegate].mxSessions[0];
        MXMyUser* myUser = session.myUser;
        
        BOOL saveButtonEnabled = (nil != newAvatarImage);
        
        if (!saveButtonEnabled)
        {
            if (newDisplayName)
            {
                saveButtonEnabled = ![myUser.displayname isEqualToString:newDisplayName];
            }
        }
        
        self.navigationItem.rightBarButtonItem.enabled = saveButtonEnabled;
    }
}

- (void)onProfileAvatarTap:(UITapGestureRecognizer *)recognizer
{
    SingleImagePickerPresenter *singleImagePickerPresenter = [[SingleImagePickerPresenter alloc] initWithSession:self.mainSession];
    singleImagePickerPresenter.delegate = self;
    
    NSIndexPath *indexPath = [self exactIndexPathForRowTag:USER_SETTINGS_PROFILE_PICTURE_INDEX
                                                sectionTag:SECTION_TAG_USER_SETTINGS];
    if (indexPath)
    {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        
        UIView *sourceView = cell;
        
        [singleImagePickerPresenter presentFrom:self sourceView:sourceView sourceRect:sourceView.bounds animated:YES];
        
        self.imagePickerPresenter = singleImagePickerPresenter;
    }
}

- (void)showThemePicker
{
    __weak typeof(self) weakSelf = self;

    __block UIAlertAction *autoAction, *lightAction, *darkAction, *blackAction;
    NSString *themePickerMessage;

    void (^actionBlock)(UIAlertAction *action) = ^(UIAlertAction * action) {

        if (weakSelf)
        {
            typeof(self) self = weakSelf;

            NSString *newTheme;
            if (action == autoAction)
            {
                newTheme = @"auto";
            }
            else  if (action == lightAction)
            {
                newTheme = @"light";
            }
            else if (action == darkAction)
            {
                newTheme = @"dark";
            }
            else if (action == blackAction)
            {
                newTheme = @"black";
            }

            NSString *theme = RiotSettings.shared.userInterfaceTheme;
            if (newTheme && ![newTheme isEqualToString:theme])
            {
                // Clear fake Riot Avatars based on the previous theme.
                [AvatarGenerator clear];

                // The user wants to select this theme
                RiotSettings.shared.userInterfaceTheme = newTheme;
                ThemeService.shared.themeId = newTheme;

                [self updateSections];
            }
        }
    };

    if (@available(iOS 11.0, *))
    {
        // Show "auto" only from iOS 11
        autoAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"settings_ui_theme_auto", @"Vector", nil)
                                              style:UIAlertActionStyleDefault
                                            handler:actionBlock];

        // Explain what is "auto"
        themePickerMessage = NSLocalizedStringFromTable(@"settings_ui_theme_picker_message", @"Vector", nil);
    }

    lightAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"settings_ui_theme_light", @"Vector", nil)
                                          style:UIAlertActionStyleDefault
                                        handler:actionBlock];

    darkAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"settings_ui_theme_dark", @"Vector", nil)
                                           style:UIAlertActionStyleDefault
                                         handler:actionBlock];
    blackAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"settings_ui_theme_black", @"Vector", nil)
                                          style:UIAlertActionStyleDefault
                                        handler:actionBlock];


    UIAlertController *themePicker = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"settings_ui_theme_picker_title", @"Vector", nil)
                                                                         message:themePickerMessage
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];

    if (autoAction)
    {
        [themePicker addAction:autoAction];
    }
    [themePicker addAction:lightAction];
    [themePicker addAction:darkAction];
    [themePicker addAction:blackAction];

    // Cancel button
    [themePicker addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"]
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil]];

    NSIndexPath *indexPath = [self exactIndexPathForRowTag:USER_INTERFACE_THEME_INDEX
                                                sectionTag:SECTION_TAG_USER_INTERFACE];
    if (indexPath)
    {
        UIView *fromCell = [self.tableView cellForRowAtIndexPath:indexPath];
        [themePicker popoverPresentationController].sourceView = fromCell;
        [themePicker popoverPresentationController].sourceRect = fromCell.bounds;
        [self presentViewController:themePicker animated:YES completion:nil];
    }
}

- (void)deactivateAccountAction
{
    DeactivateAccountViewController *deactivateAccountViewController = [DeactivateAccountViewController instantiateWithMatrixSession:self.mainSession];
    
    UINavigationController *navigationController = [[RiotNavigationController alloc] initWithRootViewController:deactivateAccountViewController];
    navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    
    [self presentViewController:navigationController animated:YES completion:nil];
    
    deactivateAccountViewController.delegate = self;
    
    self.deactivateAccountViewController = deactivateAccountViewController;
}

#pragma mark - TextField listener

- (IBAction)textFieldDidChange:(id)sender
{
    UITextField* textField = (UITextField*)sender;
    
    if (textField.tag == USER_SETTINGS_DISPLAYNAME_INDEX)
    {
        // Remove white space from both ends
        newDisplayName = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        [self updateSaveButtonStatus];
    }
}

- (IBAction)textFieldDidEnd:(id)sender
{
    UITextField* textField = (UITextField*)sender;
}

#pragma mark - UITextField delegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField.tag == USER_SETTINGS_DISPLAYNAME_INDEX)
    {
        textField.textAlignment = NSTextAlignmentLeft;
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField.tag == USER_SETTINGS_DISPLAYNAME_INDEX)
    {
        textField.textAlignment = NSTextAlignmentRight;
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField.tag == USER_SETTINGS_DISPLAYNAME_INDEX)
    {
        [textField resignFirstResponder];
    }
    
    return YES;
}

#pragma password update management

- (IBAction)passwordTextFieldDidChange:(id)sender
{
    savePasswordAction.enabled = (currentPasswordTextField.text.length > 0) && (newPasswordTextField1.text.length > 2) && [newPasswordTextField1.text isEqualToString:newPasswordTextField2.text];
}

- (void)displayPasswordAlert
{
    __weak typeof(self) weakSelf = self;
    [resetPwdAlertController dismissViewControllerAnimated:NO completion:nil];
    
    resetPwdAlertController = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"settings_change_password", @"Vector", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
    resetPwdAlertController.accessibilityLabel=@"ChangePasswordAlertController";
    savePasswordAction = [UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"save", @"Vector", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            
            self->resetPwdAlertController = nil;
            
            if ([MXKAccountManager sharedManager].activeAccounts.count > 0)
            {
                [self startActivityIndicator];
                self->isResetPwdInProgress = YES;
                
                MXKAccount* account = [MXKAccountManager sharedManager].activeAccounts.firstObject;
                
                [account changePassword:currentPasswordTextField.text with:newPasswordTextField1.text success:^{
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->isResetPwdInProgress = NO;
                        [self stopActivityIndicator];
                        
                        // Display a successful message only if the settings screen is still visible (destroy is not called yet)
                        if (!self->onReadyToDestroyHandler)
                        {
                            [self->currentAlert dismissViewControllerAnimated:NO completion:nil];
                            
                            self->currentAlert = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedStringFromTable(@"settings_password_updated", @"Vector", nil) preferredStyle:UIAlertControllerStyleAlert];
                            
                            [self->currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                                             style:UIAlertActionStyleDefault
                                                                           handler:^(UIAlertAction * action) {
                                                                               
                                                                               if (weakSelf)
                                                                               {
                                                                                   typeof(self) self = weakSelf;
                                                                                   self->currentAlert = nil;
                                                                                   
                                                                                   // Check whether destroy has been called durign pwd change
                                                                                   if (self->onReadyToDestroyHandler)
                                                                                   {
                                                                                       // Ready to destroy
                                                                                       self->onReadyToDestroyHandler();
                                                                                       self->onReadyToDestroyHandler = nil;
                                                                                   }
                                                                               }
                                                                               
                                                                           }]];
                            
                            [self->currentAlert mxk_setAccessibilityIdentifier:@"SettingsVCOnPasswordUpdatedAlert"];
                            [self presentViewController:self->currentAlert animated:YES completion:nil];
                        }
                        else
                        {
                            // Ready to destroy
                            self->onReadyToDestroyHandler();
                            self->onReadyToDestroyHandler = nil;
                        }
                    }
                    
                } failure:^(NSError *error) {
                    
                    if (weakSelf)
                    {
                        typeof(self) self = weakSelf;
                        
                        self->isResetPwdInProgress = NO;
                        [self stopActivityIndicator];
                        
                        // Display a failure message on the current screen
                        UIViewController *rootViewController = [AppDelegate theDelegate].window.rootViewController;
                        if (rootViewController)
                        {
                            [self->currentAlert dismissViewControllerAnimated:NO completion:nil];
                            
                            self->currentAlert = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedStringFromTable(@"settings_fail_to_update_password", @"Vector", nil) preferredStyle:UIAlertControllerStyleAlert];
                            
                            [self->currentAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                                                   style:UIAlertActionStyleDefault
                                                                                 handler:^(UIAlertAction * action) {
                                                                                     
                                                                                     if (weakSelf)
                                                                                     {
                                                                                         typeof(self) self = weakSelf;
                                                                                         
                                                                                         self->currentAlert = nil;
                                                                                         
                                                                                         // Check whether destroy has been called durign pwd change
                                                                                         if (self->onReadyToDestroyHandler)
                                                                                         {
                                                                                             // Ready to destroy
                                                                                             self->onReadyToDestroyHandler();
                                                                                             self->onReadyToDestroyHandler = nil;
                                                                                         }
                                                                                     }
                                                                                     
                                                                                 }]];
                            
                            [self->currentAlert mxk_setAccessibilityIdentifier:@"SettingsVCPasswordChangeFailedAlert"];
                            [rootViewController presentViewController:self->currentAlert animated:YES completion:nil];
                        }
                    }
                    
                }];
            }
        }
        
    }];
    
    // disable by default
    // check if the textfields have the right value
    savePasswordAction.enabled = NO;
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            
            self->resetPwdAlertController = nil;
        }
        
    }];
    
    [resetPwdAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            
            self->currentPasswordTextField = textField;
            self->currentPasswordTextField.placeholder = NSLocalizedStringFromTable(@"settings_old_password", @"Vector", nil);
            self->currentPasswordTextField.secureTextEntry = YES;
            [self->currentPasswordTextField addTarget:self action:@selector(passwordTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        }
         
     }];
    
    [resetPwdAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            
            self->newPasswordTextField1 = textField;
            self->newPasswordTextField1.placeholder = NSLocalizedStringFromTable(@"settings_new_password", @"Vector", nil);
            self->newPasswordTextField1.secureTextEntry = YES;
            [self->newPasswordTextField1 addTarget:self action:@selector(passwordTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        }
        
    }];
    
    [resetPwdAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            
            self->newPasswordTextField2 = textField;
            self->newPasswordTextField2.placeholder = NSLocalizedStringFromTable(@"settings_confirm_password", @"Vector", nil);
            self->newPasswordTextField2.secureTextEntry = YES;
            [self->newPasswordTextField2 addTarget:self action:@selector(passwordTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        }
    }];

    
    [resetPwdAlertController addAction:cancel];
    [resetPwdAlertController addAction:savePasswordAction];
    [self presentViewController:resetPwdAlertController animated:YES completion:nil];
}

#pragma mark - MXKCountryPickerViewControllerDelegate

- (void)languagePickerViewController:(MXKLanguagePickerViewController *)languagePickerViewController didSelectLangugage:(NSString *)language
{
    [languagePickerViewController withdrawViewControllerAnimated:YES completion:nil];

    if (![language isEqualToString:[NSBundle mxk_language]]
        || (language == nil && [NSBundle mxk_language]))
    {
        [NSBundle mxk_setLanguage:language];

        // Store user settings
        NSUserDefaults *sharedUserDefaults = [MXKAppSettings standardAppSettings].sharedUserDefaults;
        [sharedUserDefaults setObject:language forKey:@"appLanguage"];

        // Do a reload in order to recompute strings in the new language
        // Note that "reloadMatrixSessions:NO" will reset room summaries
        [self startActivityIndicator];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{

            [[AppDelegate theDelegate] reloadMatrixSessions:NO];
        });
    }
}

#pragma mark - MXKDataSourceDelegate

- (Class<MXKCellRendering>)cellViewClassForCellData:(MXKCellData*)cellData
{
    // Return the class used to display a group with a toogle button
    return GroupTableViewCellWithSwitch.class;
}

- (NSString *)cellReuseIdentifierForCellData:(MXKCellData*)cellData
{
    return GroupTableViewCellWithSwitch.defaultReuseIdentifier;
}

- (void)dataSource:(MXKDataSource *)dataSource didCellChange:(id)changes
{
    // Group data has been updated. Do a simple full reload
    [self refreshSettings];
}

#pragma mark - DeactivateAccountViewControllerDelegate

- (void)deactivateAccountViewControllerDidDeactivateWithSuccess:(DeactivateAccountViewController *)deactivateAccountViewController
{
    NSLog(@"[SettingsViewController] Deactivate account with success");
    
    [[AppDelegate theDelegate] logoutSendingRequestServer:NO completion:^(BOOL isLoggedOut) {
        NSLog(@"[SettingsViewController] Complete clear user data after account deactivation");
    }];
}

- (void)deactivateAccountViewControllerDidCancel:(DeactivateAccountViewController *)deactivateAccountViewController
{
    [deactivateAccountViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - SecureBackupSetupCoordinatorBridgePresenter

- (void)showSecureBackupSetupFromSignOutFlow
{
    if (self.canSetupSecureBackup)
    {
        [self setupSecureBackup2];
    }
    else
    {
        // Set up cross-signing first
        [self setupCrossSigningWithTitle:NSLocalizedStringFromTable(@"secure_key_backup_setup_intro_title", @"Vector", nil)
                                 message:NSLocalizedStringFromTable(@"security_settings_user_password_description", @"Vector", nil)
                                 success:^{
                                     [self setupSecureBackup2];
                                 } failure:^(NSError *error) {
                                 }];
    }
}

- (void)setupSecureBackup2
{
    SecureBackupSetupCoordinatorBridgePresenter *secureBackupSetupCoordinatorBridgePresenter = [[SecureBackupSetupCoordinatorBridgePresenter alloc] initWithSession:self.mainSession];
    secureBackupSetupCoordinatorBridgePresenter.delegate = self;
    
    [secureBackupSetupCoordinatorBridgePresenter presentFrom:self animated:YES];
    
    self.secureBackupSetupCoordinatorBridgePresenter = secureBackupSetupCoordinatorBridgePresenter;
}

- (BOOL)canSetupSecureBackup
{
    // Accept to create a setup only if we have the 3 cross-signing keys
    // This is the path to have a sane state
    // TODO: What about missing MSK that was not gossiped before?
    
    MXRecoveryService *recoveryService = self.mainSession.crypto.recoveryService;
    
    NSArray *crossSigningServiceSecrets = @[
                                            MXSecretId.crossSigningMaster,
                                            MXSecretId.crossSigningSelfSigning,
                                            MXSecretId.crossSigningUserSigning];
    
    return ([recoveryService.secretsStoredLocally mx_intersectArray:crossSigningServiceSecrets].count
            == crossSigningServiceSecrets.count);
}

#pragma mark - SecureBackupSetupCoordinatorBridgePresenterDelegate

- (void)secureBackupSetupCoordinatorBridgePresenterDelegateDidComplete:(SecureBackupSetupCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [self.secureBackupSetupCoordinatorBridgePresenter dismissWithAnimated:YES completion:nil];
    self.secureBackupSetupCoordinatorBridgePresenter = nil;
}

- (void)secureBackupSetupCoordinatorBridgePresenterDelegateDidCancel:(SecureBackupSetupCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [self.secureBackupSetupCoordinatorBridgePresenter dismissWithAnimated:YES completion:nil];
    self.secureBackupSetupCoordinatorBridgePresenter = nil;
}

#pragma mark - SignOutAlertPresenterDelegate

- (void)signOutAlertPresenterDidTapBackupAction:(SignOutAlertPresenter * _Nonnull)presenter
{
    [self showSecureBackupSetupFromSignOutFlow];
}

- (void)signOutAlertPresenterDidTapSignOutAction:(SignOutAlertPresenter * _Nonnull)presenter
{
    // Prevent user to perform user interaction in settings when sign out
    // TODO: Prevent user interaction in all application (navigation controller and split view controller included)
    self.view.userInteractionEnabled = NO;
    self.signOutButton.enabled = NO;
    
    [self startActivityIndicator];
    
    MXWeakify(self);
    
    [[AppDelegate theDelegate] logoutWithConfirmation:NO completion:^(BOOL isLoggedOut) {
        MXStrongifyAndReturnIfNil(self);
        
        [self stopActivityIndicator];
        
        self.view.userInteractionEnabled = YES;
        self.signOutButton.enabled = YES;
    }];
}

- (void)setupCrossSigningWithTitle:(NSString*)title
                           message:(NSString*)message
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure
{
    __block UIViewController *viewController;
    [self startActivityIndicator];
    
    // Get credentials to set up cross-signing
    NSString *path = [NSString stringWithFormat:@"%@/keys/device_signing/upload", kMXAPIPrefixPathUnstable];
    _authenticatedSessionViewControllerFactory = [[AuthenticatedSessionViewControllerFactory alloc] initWithSession:self.mainSession];
    [_authenticatedSessionViewControllerFactory viewControllerForPath:path
                                                           httpMethod:@"POST"
                                                                title:title
                                                              message:message
                                                     onViewController:^(UIViewController * _Nonnull theViewController)
     {
         viewController = theViewController;
         [self presentViewController:viewController animated:YES completion:nil];
         
     } onAuthenticated:^(NSDictionary * _Nonnull authParams) {
         
         [viewController dismissViewControllerAnimated:NO completion:nil];
         viewController = nil;
         
         MXCrossSigning *crossSigning = self.mainSession.crypto.crossSigning;
         if (crossSigning)
         {
             [crossSigning setupWithAuthParams:authParams success:^{
                 [self stopActivityIndicator];
                 success();
             } failure:^(NSError * _Nonnull error) {
                 [self stopActivityIndicator];
                 
                 [[AppDelegate theDelegate] showErrorAsAlert:error];
                 failure(error);
             }];
         }
         
     } onCancelled:^{
         [self stopActivityIndicator];
         
         [viewController dismissViewControllerAnimated:NO completion:nil];
         viewController = nil;
         failure(nil);
     } onFailure:^(NSError * _Nonnull error) {
         
         [self stopActivityIndicator];
         [[AppDelegate theDelegate] showErrorAsAlert:error];
         
         [viewController dismissViewControllerAnimated:NO completion:nil];
         viewController = nil;
         failure(error);
     }];
}


#pragma mark - SingleImagePickerPresenterDelegate

- (void)singleImagePickerPresenterDidCancel:(SingleImagePickerPresenter *)presenter
{
    [presenter dismissWithAnimated:YES completion:nil];
    self.imagePickerPresenter = nil;
}

- (void)singleImagePickerPresenter:(SingleImagePickerPresenter *)presenter didSelectImageData:(NSData *)imageData withUTI:(MXKUTI *)uti
{
    [presenter dismissWithAnimated:YES completion:nil];
    self.imagePickerPresenter = nil;
    
    newAvatarImage = [UIImage imageWithData:imageData];
    
    [self updateSections];
}


#pragma mark - Identity Server updates

- (void)registerAccountDataDidChangeIdentityServerNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAccountDataDidChangeIdentityServerNotification:) name:kMXSessionAccountDataDidChangeIdentityServerNotification object:nil];
}

- (void)handleAccountDataDidChangeIdentityServerNotification:(NSNotification*)notification
{
    [self refreshSettings];
}

#pragma mark - SettingsDiscoveryTableViewSectionDelegate

- (void)settingsDiscoveryTableViewSectionDidUpdate:(SettingsDiscoveryTableViewSection *)settingsDiscoveryTableViewSection
{
    [self updateSections];
}

- (MXKTableViewCell *)settingsDiscoveryTableViewSection:(SettingsDiscoveryTableViewSection *)settingsDiscoveryTableViewSection tableViewCellClass:(Class)tableViewCellClass forRow:(NSInteger)forRow
{
    MXKTableViewCell *tableViewCell;
    
    if ([tableViewCellClass isEqual:[MXKTableViewCell class]])
    {
        tableViewCell = [self getDefaultTableViewCell:self.tableView];
    }
    else if ([tableViewCellClass isEqual:[MXKTableViewCellWithButton class]])
    {
        MXKTableViewCellWithButton *cell = [self.tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButton defaultReuseIdentifier]];
        
        if (!cell)
        {
            cell = [[MXKTableViewCellWithButton alloc] init];
        }
        else
        {
            // Fix https://github.com/vector-im/riot-ios/issues/1354
            cell.mxkButton.titleLabel.text = nil;
        }
        
        cell.mxkButton.titleLabel.font = [UIFont systemFontOfSize:17];
        [cell.mxkButton setTintColor:ThemeService.shared.theme.tintColor];
        
        tableViewCell = cell;
    }
    
    return tableViewCell;
}

#pragma mark - SettingsDiscoveryViewModelCoordinatorDelegate

- (void)settingsDiscoveryViewModel:(SettingsDiscoveryViewModel *)viewModel didSelectThreePidWith:(NSString *)medium and:(NSString *)address
{
    SettingsDiscoveryThreePidDetailsCoordinatorBridgePresenter *discoveryThreePidDetailsPresenter = [[SettingsDiscoveryThreePidDetailsCoordinatorBridgePresenter alloc] initWithSession:self.mainSession medium:medium adress:address];
    
    MXWeakify(self);
    
    [discoveryThreePidDetailsPresenter pushFrom:self.navigationController animated:YES popCompletion:^{
        MXStrongifyAndReturnIfNil(self);
        
        self.discoveryThreePidDetailsPresenter = nil;
    }];
    
    self.discoveryThreePidDetailsPresenter = discoveryThreePidDetailsPresenter;
}


#pragma mark - Identity Server

- (void)showIdentityServerSettingsScreen
{
    identityServerSettingsCoordinatorBridgePresenter = [[SettingsIdentityServerCoordinatorBridgePresenter alloc] initWithSession:self.mainSession];

    [identityServerSettingsCoordinatorBridgePresenter pushFrom:self.navigationController animated:YES popCompletion:nil];
    identityServerSettingsCoordinatorBridgePresenter.delegate = self;
}

#pragma mark - SettingsIdentityServerCoordinatorBridgePresenterDelegate

- (void)settingsIdentityServerCoordinatorBridgePresenterDelegateDidComplete:(SettingsIdentityServerCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    identityServerSettingsCoordinatorBridgePresenter = nil;
    [self refreshSettings];
}

@end
