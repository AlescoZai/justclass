import 'dart:async';

import 'package:flutter/material.dart';
import 'package:justclass/models/member.dart';
import 'package:justclass/providers/auth.dart';
import 'package:justclass/providers/member_manager.dart';
import 'package:justclass/utils/validators.dart';
import 'package:justclass/widgets/app_icon_button.dart';
import 'package:justclass/widgets/app_snack_bar.dart';
import 'package:justclass/widgets/member_avatar.dart';
import 'package:justclass/widgets/opaque_progress_indicator.dart';
import 'package:provider/provider.dart';

class InviteCollaboratorScreen extends StatefulWidget {
  final MemberManager memberMgr;
  final Color color;
  final String cid;

  InviteCollaboratorScreen({
    @required this.memberMgr,
    @required this.color,
    @required this.cid,
  });

  @override
  _InviteCollaboratorScreenState createState() => _InviteCollaboratorScreenState();
}

class _InviteCollaboratorScreenState extends State<InviteCollaboratorScreen> {
  // a flag to stop everything from running
  bool nothingView = true;

  // a flag indicating that whether suggested members are fetching
  bool isFetching = false;

  /// Only the last request having the highest index can affect UI (index == requestCount),
  /// which helps avoid collisions on UI when lots of requests are sent too fast by the user.
  int requestCount = 0;

  // a list of suggested members fetched from api
  List<Member> members;

  // a timer used to set timeout for the method of fetching suggested members
  Timer timer;

  // a list of chosen emails that user wants to invite
  final emails = Set<String>();
  bool areEmailsValid = false;

  //  a flag switching between suggested member list and entered recipient
  bool suggesting = true;

  // used to set input value to empty string after user choosing an email
  final inputCtrl = TextEditingController();

  // a flag indicating if invitations are being sent or not
  bool sending = false;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void onInputChange(String val, BuildContext context) {
    if (val == '')
      backToFirstMode();
    else {
      nothingView = false;
      if (InviteTeacherValidator.validateEmail(val) == null) {
        setState(() {
          suggesting = false;
          isFetching = false;
          members = null;
        });
      } else {
        timer?.cancel();
        setState(() => suggesting = true);
        timer = Timer(const Duration(milliseconds: 500), () => showSuggestions(val, context));
      }
    }
  }

  void backToFirstMode() {
    nothingView = true;
    timer?.cancel();
    setState(() {
      isFetching = false;
      suggesting = true;
      members = null;
    });
  }

  Future<void> showSuggestions(String val, BuildContext context) async {
    if (suggesting) setState(() => isFetching = true);
    requestCount++;
    final index = requestCount;
    try {
      final uid = Provider.of<Auth>(context, listen: false).user.uid;
      final suggestedMembers = await widget.memberMgr.fetchSuggestedCollaborators(uid, widget.cid, val);

      // only the result of last request is assigned
      if (index == requestCount && !nothingView && suggesting && this.mounted)
        setState(() => members = suggestedMembers);
    } catch (error) {
      if (this.mounted && suggesting) AppSnackBar.showError(context, message: error.toString());
    } finally {
      if (index == requestCount && this.mounted && suggesting) setState(() => isFetching = false);
    }
  }

  void onSelectMember(String email) {
    inputCtrl.clear();
    backToFirstMode();
    emails.add(email);
    checkValidEmailList();
  }

  void removeEmail(String email) {
    emails.remove(email);
    checkValidEmailList();
  }

  void checkValidEmailList() {
    setState(() {
      areEmailsValid = emails.isNotEmpty;
    });
  }

  void sendInvitations() {
    setState(() => sending = true);
    try {
      final uid = Provider.of<Auth>(context, listen: false).user.uid;
      widget.memberMgr.inviteCollaborators(uid, widget.cid, emails);
    } catch (error) {
      if (this.mounted) AppSnackBar.showError(context, message: error.toString());
    } finally {
      if (this.mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      child: Scaffold(
        backgroundColor: widget.color,
        appBar: _buildTopBar(context, widget.color, 'Invite teachers'),
        body: SafeArea(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
            child: Container(
              color: Colors.white,
              height: double.infinity,
              child: Stack(
                children: <Widget>[
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (emails.isNotEmpty) _buildEmailList(),
                        _buildTextField(),
                        _buildLoadingIndicator(),
                        if (members != null) _buildSuggestedMemberList(),
                        if (members == null && !suggesting) _buildRecipientBtn(inputCtrl.text),
                      ],
                    ),
                  ),
                  Visibility(
                    visible: sending,
                    child: OpaqueProgressIndicator(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientBtn(String email) {
    return ListTile(
      trailing: MemberAvatar(color: widget.color, displayName: email),
      title: Text('Add recipient'),
      subtitle: Text(email, overflow: TextOverflow.ellipsis),
      onTap: () => onSelectMember(email),
    );
  }

  Widget _buildEmailList() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 0),
      child: Wrap(
        spacing: 10,
        children: <Widget>[
          ...emails
              .map(
                (m) => Chip(
                  label: Text(m, overflow: TextOverflow.ellipsis),
                  deleteIcon: const Icon(Icons.clear, color: Colors.black45, size: 18),
                  onDeleted: () => removeEmail(m),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildSuggestedMemberList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.all(10),
            child: const Text('No suggestions', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ),
        if (members.isNotEmpty)
          ...members
              .map((m) => ListTile(
                    trailing: MemberAvatar(color: widget.color, displayName: m.displayName, photoUrl: m.photoUrl),
                    title: Text(m.displayName, overflow: TextOverflow.ellipsis),
                    subtitle: Text(m.email, overflow: TextOverflow.ellipsis),
                    onTap: () => onSelectMember(m.email),
                  ))
              .toList(),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      height: 4,
      child: (isFetching)
          ? LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation(widget.color),
              backgroundColor: widget.color.withOpacity(0.5),
            )
          : Divider(color: widget.color, height: 0.5),
    );
  }

  Widget _buildTextField() {
    return Builder(
      builder: (context) {
        return TextField(
          controller: inputCtrl,
          autofocus: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(20),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.transparent)),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.transparent)),
            labelText: 'Name or email address',
            hasFloatingPlaceholder: false,
          ),
          onChanged: (val) => onInputChange(val, context),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, Color bgColor, String title) {
    return AppBar(
      elevation: 0,
      backgroundColor: bgColor,
      leading: AppIconButton.cancel(onPressed: () => Navigator.of(context).pop()),
      title: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17)),
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 5),
          child: AppIconButton(
            icon: const Icon(Icons.send, size: 22),
            tooltip: 'Send invitations',
            onPressed: !areEmailsValid ? null : sendInvitations,
          ),
        ),
      ],
    );
  }
}
