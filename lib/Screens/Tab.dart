import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hookup4u/Screens/Profile/profile.dart';
import 'package:hookup4u/Screens/Splash.dart';
import 'package:hookup4u/Screens/blockUserByAdmin.dart';
import 'package:hookup4u/Screens/notifications.dart';
import 'package:hookup4u/models/user_model.dart' as userD;
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:rflutter_alert/rflutter_alert.dart';
import 'Calling/incomingCall.dart';
import 'Chat/home_screen.dart';
import 'Home.dart';
import 'package:hookup4u/util/color.dart';
import 'package:easy_localization/easy_localization.dart';

List likedByList = [];

class Tabbar extends StatefulWidget {
  final bool? isPaymentSuccess;
  final String? plan;
  Tabbar(this.plan, this.isPaymentSuccess);
  @override
  TabbarState createState() => TabbarState();
}

//_
class TabbarState extends State<Tabbar> {
  //late FirebaseMessaging _firebaseMessaging;
  CollectionReference docRef = FirebaseFirestore.instance.collection('Users');
  FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  userD.User? currentUser;
  List<userD.User> matches = [];
  List<userD.User> newmatches = [];

  List<userD.User> users = [];
  Map likedMap = {};
  Map disLikedMap = {};

  /// Past purchases
  List<PurchaseDetails> purchases = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  //previous code
  //InAppPurchaseConnection _iap = InAppPurchaseConnection.instance;
  InAppPurchase _iap = InAppPurchase.instance;
  bool isPuchased = false;
  @override
  void initState() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    print('===purchaseUpdated=====${purchaseUpdated.first}');
    _subscription = purchaseUpdated.listen((purchaseDetailsList) async {
      print('========${purchaseDetailsList.length}');

      setState(() {
        purchases.addAll(purchaseDetailsList);
        _listenToPurchaseUpdated(purchaseDetailsList);
      });
    }, onDone: () {
      print('===purchaseUpdated=====done');
      _subscription!.cancel();
    }, onError: (error) {
      print('===purchaseUpdated=====cancel');
      _subscription!.cancel();
    });

    super.initState();
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => Incoming(message.data)));
      } else {}
    });
    // Show payment success alert.
    if (widget.isPaymentSuccess != null && widget.isPaymentSuccess!) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Alert(
          context: context,
          type: AlertType.success,
          title: "Confirmation".tr().toString(),
          desc: "You have successfully subscribed to our"
              .tr(args: ['${widget.plan}']).toString(),
          buttons: [
            DialogButton(
              child: Text(
                "Ok".tr().toString(),
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              onPressed: () => Navigator.pop(context),
              width: 120,
            )
          ],
        ).show();
      });
    }
    _getAccessItems();
    _getCurrentUser();
    _getMatches();
    _getpastPurchases();
  }

  @override
  void dispose() {
    _subscription!.cancel();
    super.dispose();
  }

  Map items = {};
  _getAccessItems() async {
    FirebaseFirestore.instance
        .collection("Item_access")
        .snapshots()
        .listen((doc) {
      if (doc.docs.length > 0) {
        items = doc.docs[0].data();
        print(doc.docs[0].data());
      }

      if (mounted) setState(() {});
    });
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      print('========${purchaseDetails.status}');

      if (purchaseDetails.status == purchaseDetails.status) {
        print('===in if stmnt  ${purchaseDetails.productID}');
        await _verifyPuchase(purchaseDetails.productID);
      }
      // switch (purchaseDetails.status) {
      //   case PurchaseStatus.pending:
      //     //  _showPendingUI();
      //     break;
      //   case PurchaseStatus.purchased:
      //   case purchaseDetails.status
      //     await _verifyPuchase(purchaseDetails.productID);
      //     // bool valid = await _verifyPurchase(purchaseDetails);
      //     // if (!valid) {
      //     //   _handleInvalidPurchase(purchaseDetails);
      //     // }
      //     break;
      //   case PurchaseStatus.error:
      //     print(purchaseDetails.error!);
      //     // _handleError(purchaseDetails.error!);
      //     break;
      //   default:
      //     break;
      // }

      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
    });
  }
  // Future<void> _getpastPurchases() async {
  //   //previous code
  //   QueryPurchaseDetailsResponse response = await _iap.queryProductDetails();
  //    await _iap.restorePurchases();

  //   for (PurchaseDetails purchase in response) {
  //     // if (Platform.isIOS) {
  //     await _iap.completePurchase(purchase);
  //     // }
  //   }
  //   setState(() {
  //     purchases = response.pastPurchases;
  //   });
  //   if (response.pastPurchases.length > 0) {
  //     purchases.forEach((purchase) async {
  //       print('   ${purchase.productID}');
  //       await _verifyPuchase(purchase.productID);
  //     });
  //   }
  // }

  /// check if user has pruchased
  PurchaseDetails _hasPurchased(String productId) {
    print('======**************');
    return purchases.firstWhere(
      (purchase) => purchase.productID == productId,
      // orElse: () => null
    );
  }

  ///verifying pourchase of user
  Future<void> _verifyPuchase(String id) async {
    print('===**************');
    PurchaseDetails purchase = _hasPurchased(id);
    print('===******** ${purchase.purchaseID}');
    print('===******** ${purchase.status}');
    if (purchase != null && purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      print(purchase.productID);
      if (Platform.isIOS) {
        await _iap.completePurchase(purchase);

        isPuchased = true;
      }
      isPuchased = true;
    } else {
      isPuchased = false;
    }
  }

  int swipecount = 0;
  _getSwipedcount() {
    FirebaseFirestore.instance
        .collection('/Users/${currentUser!.id}/CheckedUser')
        .where(
          'timestamp',
          isGreaterThan: Timestamp.now().toDate().subtract(Duration(days: 1)),
        )
        .snapshots()
        .listen((event) {
      print(event.docs.length);
      setState(() {
        swipecount = event.docs.length;
      });
      //return event.documents.length;
      //return swipecount;
    });
    return swipecount;
  }

  configurePushNotification(userD.User user) async {
    await FirebaseMessaging.instance
        .requestPermission(
            alert: true, badge: true, sound: true, provisional: false)
        .then((value) {
      return null;
    });

    FirebaseMessaging.instance.getToken().then((token) {
      print('token)))))))))$token');
      docRef.doc(user.id).update({
        'pushToken': token,
      });
    });
    //FirebaseMessaging.instance.

    // FirebaseMessaging.instance
    //     .getInitialMessage()
    //     .then((RemoteMessage? message) async {
    //   print('getInitialMessage data: ${message}');
    // });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("onMessage data: ${message.data}");
      print("onmessage${message.data['type']}");

      if (Platform.isIOS && message.data['type'] == 'Call') {
        Map callInfo = {};
        callInfo['channel_id'] = message.data['channel_id'];
        callInfo['senderName'] = message.data['senderName'];
        callInfo['senderPicture'] = message.data['senderPicture'];
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => Incoming(callInfo)));
      } else if (Platform.isAndroid && message.data['type'] == 'Call') {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => Incoming(message.data)));
      } else
        print("object>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
    });

    // replacement for onResume: When the app is in the background and opened directly from the push notification.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      print('onMessageOpenedApp data: ${message.data}');
      if (Platform.isIOS && message.data['type'] == 'Call') {
        Map callInfo = {};
        callInfo['channel_id'] = message.data['channel_id'];
        callInfo['senderName'] = message.data['senderName'];
        callInfo['senderPicture'] = message.data['senderPicture'];
        bool iscallling = _checkcallState(message.data['channel_id']);
        print("=================$iscallling");
        if (iscallling) {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => Incoming(message.data)));
        }
      } else if (Platform.isAndroid && message.data['type'] == 'Call') {
        bool iscallling = await _checkcallState(message.data['channel_id']);
        print("=================$iscallling");
        if (iscallling) {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => Incoming(message.data)));
        } else {
          print("Timeout");
        }
      }
    });

    // FirebaseMessaging.onMessage.listen((event) async {
    //   print("onmessage${event.data['data']['type']}");

    //   if (Platform.isIOS && event.data['type'] == 'Call') {
    //     Map callInfo = {};
    //     callInfo['channel_id'] = event.data['channel_id'];
    //     callInfo['senderName'] = event.data['senderName'];
    //     callInfo['senderPicture'] = event.data['senderPicture'];
    //     await Navigator.push(context,
    //         MaterialPageRoute(builder: (context) => Incoming(callInfo)));
    //   } else if (Platform.isAndroid && event.data['data']['type'] == 'Call') {
    //     print('=======================tttttttttttttttttttt');
    //     await Navigator.push(
    //         context,
    //         MaterialPageRoute(
    //             builder: (context) => Incoming(event.data['data'])));
    //   } else
    //     print("object>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
    // });

    // FirebaseMessaging.onMessageOpenedApp.listen((event) async {
    //   print('===============onLaunch$event');
    //   if (Platform.isIOS && event.data['type'] == 'Call') {
    //     Map callInfo = {};
    //     callInfo['channel_id'] = event.data['channel_id'];
    //     callInfo['senderName'] = event.data['senderName'];
    //     callInfo['senderPicture'] = event.data['senderPicture'];
    //     bool iscallling = await _checkcallState(event.data['channel_id']);
    //     print("=================$iscallling");
    //     if (iscallling) {
    //       print('######################');
    //       await Navigator.push(context,
    //           MaterialPageRoute(builder: (context) => Incoming(event.data)));
    //     }
    //   } else if (Platform.isAndroid && event.data['data']['type'] == 'Call') {
    //     bool iscallling =
    //         await _checkcallState(event.data['data']['channel_id']);
    //     print("=================$iscallling");
    //     if (iscallling) {
    //       await Navigator.push(
    //           context,
    //           MaterialPageRoute(
    //               builder: (context) => Incoming(event.data['data'])));
    //     } else {
    //       print("Timeout");
    //     }
    //   }
    // });
  }

  _checkcallState(channelId) async {
    bool iscalling = await FirebaseFirestore.instance
        .collection("calls")
        .doc(channelId)
        .get()
        .then((value) {
      return value.data()!["calling"] ?? false;
    });
    return iscalling;
  }

  _getMatches() async {
    User user = await _firebaseAuth.currentUser!;
    return FirebaseFirestore.instance
        .collection('/Users/${user.uid}/Matches')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((ondata) {
      matches.clear();
      newmatches.clear();
      if (ondata.docs.length > 0) {
        ondata.docs.forEach((f) async {
          await docRef
              .doc(f.data()['Matches'])
              .get()
              .then((DocumentSnapshot doc) {
            if (doc.exists) {
              userD.User tempuser = userD.User.fromDocument(doc);
              tempuser.distanceBW = calculateDistance(
                      currentUser!.coordinates!['latitude'],
                      currentUser!.coordinates!['longitude'],
                      tempuser.coordinates!['latitude'],
                      tempuser.coordinates!['longitude'])
                  .round();

              matches.add(tempuser);
              newmatches.add(tempuser);
              if (mounted) setState(() {});
            }
          });
        });
      }
    });
  }

  _getCurrentUser() async {
    User? user = await _firebaseAuth.currentUser;

    docRef.doc("${user!.uid}").snapshots().listen((data) async {
      currentUser = userD.User.fromDocument(data);
      print('----------------$currentUser');
      if (mounted) setState(() {});
      users.clear();
      userRemoved.clear();
      getUserList();
      getLikedByList();
      configurePushNotification(currentUser!);
      if (!isPuchased) {
        _getSwipedcount();
      }
      //return currentUser;
    }).onError(print);
    return currentUser;
  }

  Query query() {
    if (currentUser!.showGender == 'everyone') {
      return docRef
          .where(
            'age',
            isGreaterThanOrEqualTo: int.parse(currentUser!.ageRange!['min']),
          )
          .where('age',
              isLessThanOrEqualTo: int.parse(currentUser!.ageRange!['max']))
          .orderBy('age', descending: false);
    } else {
      return docRef
          .where('editInfo.userGender', isEqualTo: currentUser!.showGender)
          .where(
            'age',
            isGreaterThanOrEqualTo: int.parse(currentUser!.ageRange!['min']),
          )
          .where('age',
              isLessThanOrEqualTo: int.parse(currentUser!.ageRange!['max']))
          //FOR FETCH USER WHO MATCH WITH USER SEXUAL ORIENTAION
          // .where('sexualOrientation.orientation',
          //     arrayContainsAny: currentUser.sexualOrientation)
          .orderBy('age', descending: false);
    }
  }

  Future getUserList() async {
    List checkedUser = [];

    FirebaseFirestore.instance
        .collection('/Users/${currentUser!.id}/CheckedUser')
        .get()
        .then((event) {
      if (event.docs.length > 0) {
        event.docs.forEach((element) async {
          checkedUser.add(element.data()['LikedUser']);
          checkedUser.add(element.data()['DislikedUser']);
        });
      }
    }).then((v) {
      query().get().then((data) async {
        if (data.docs.length < 1) {
          print("no more data");
          return;
        }
        users.clear();
        userRemoved.clear();
        for (var doc in data.docs) {
          userD.User temp = userD.User.fromDocument(doc);
          var distance = calculateDistance(
              currentUser!.coordinates!['latitude'],
              currentUser!.coordinates!['longitude'],
              temp.coordinates!['latitude'],
              temp.coordinates!['longitude']);
          temp.distanceBW = distance.round();
          if (checkedUser.any(
            (value) {
              return value == temp.id;
            },
          )) {
          } else {
            if (distance <= currentUser!.maxDistance! &&
                temp.id != currentUser!.id &&
                !temp.isBlocked!) {
              users.add(temp);
            }
          }
        }
        if (mounted) setState(() {});
      });
    });
  }

  getLikedByList() {
    docRef
        .doc(currentUser!.id)
        .collection("LikedBy")
        .snapshots()
        .listen((data) async {
      likedByList.addAll(data.docs.map((f) => f['LikedBy']));
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: currentUser == null
            ? Center(child: Splash())
            : currentUser!.isBlocked!
                ? BlockUser()
                : DefaultTabController(
                    length: 4,
                    initialIndex: widget.isPaymentSuccess != null
                        ? widget.isPaymentSuccess!
                            ? 0
                            : 1
                        : 1,
                    child: Scaffold(
                        appBar: AppBar(
                          elevation: 0,
                          backgroundColor: primaryColor,
                          automaticallyImplyLeading: false,
                          title: TabBar(
                              labelColor: Colors.white,
                              indicatorColor: Colors.white,
                              unselectedLabelColor: Colors.black,
                              isScrollable: false,
                              indicatorSize: TabBarIndicatorSize.label,
                              tabs: [
                                Tab(
                                  icon: Icon(
                                    Icons.person,
                                    size: 30,
                                  ),
                                ),
                                Tab(
                                  icon: Icon(
                                    Icons.whatshot,
                                  ),
                                ),
                                Tab(
                                  icon: Icon(
                                    Icons.notifications,
                                  ),
                                ),
                                Tab(
                                  icon: Icon(
                                    Icons.message,
                                  ),
                                )
                              ]),
                        ),
                        body: TabBarView(
                          children: [
                            Center(
                                child: Profile(currentUser!, isPuchased,
                                    purchases, items)),
                            Center(
                                child: CardPictures(
                                    currentUser!, users, swipecount, items)),
                            Center(child: Notifications(currentUser!)),
                            Center(
                                child: HomeScreen(
                                    currentUser!, matches, newmatches)),
                          ],
                          physics: NeverScrollableScrollPhysics(),
                        )),
                  ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Exit'.tr().toString()),
          content: Text('Do you want to exit the app?'.tr().toString()),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'.tr().toString()),
            ),
            TextButton(
              onPressed: () =>
                  SystemChannels.platform.invokeMethod('SystemNavigator.pop'),
              child: Text('Yes'.tr().toString()),
            ),
          ],
        );
      },
    );
    return true;
  }

  Future<void> _getpastPurchases() async {
    await _iap.restorePurchases();
  }
}

double calculateDistance(lat1, lon1, lat2, lon2) {
  var p = 0.017453292519943295;
  var c = cos;
  var a = 0.5 -
      c((lat2 - lat1) * p) / 2 +
      c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * asin(sqrt(a));
}
