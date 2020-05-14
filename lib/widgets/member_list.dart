import 'package:flutter/material.dart';
import 'package:justclass/models/member.dart';
import 'package:justclass/providers/auth.dart';
import 'package:justclass/providers/class.dart';
import 'package:justclass/themes.dart';
import 'package:justclass/widgets/app_snack_bar.dart';
import 'package:justclass/widgets/refreshable_error_prompt.dart';
import 'package:justclass/widgets/student_member_list.dart';
import 'package:justclass/widgets/teacher_member_list.dart';
import 'package:provider/provider.dart';

import 'fetch_progress_indicator.dart';

class MemberList extends StatefulWidget {
  @override
  _MemberListState createState() => _MemberListState();
}

class _MemberListState extends State<MemberList> {
  bool hasError = false;
  bool didFirstLoad = false;

  List<Member> getTeacherList(List<Member> members) {
    List<Member> teachers = [];
    teachers.add(members.firstWhere((m) => m.role == ClassRole.OWNER));
    teachers.addAll(members.where((m) => m.role == ClassRole.COLLABORATOR));
    return teachers;
  }

  List<Member> getStudentList(List<Member> members) {
    return members.where((m) => m.role == ClassRole.STUDENT).toList();
  }

  Future<void> fetchMemberListFirstLoad(Class cls, String uid) async {
    try {
      await cls.fetchMemberList(uid);
      setState(() {
        didFirstLoad = true;
      });
    } catch (error) {
      if (this.mounted) AppSnackBar.showError(context, message: error.toString());
      setState(() {
        didFirstLoad = true;
        hasError = true;
      });
    }
  }

  Future<void> fetchMemberList(Class cls, String uid) async {
    try {
      await cls.fetchMemberList(uid);
      setState(() => hasError = false);
    } catch (error) {
      if (this.mounted) AppSnackBar.showError(context, message: error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cls = Provider.of<Class>(context);
//    final uid = Provider.of<Auth>(context, listen: false).user.uid;
    final uid = '1';

    if (!didFirstLoad && cls.members == null) {
      fetchMemberListFirstLoad(cls, uid);
      return FetchProgressIndicator();
    }
    return (hasError)
        ? RefreshableErrorPrompt(onRefresh: () => fetchMemberList(cls, uid))
        : RefreshIndicator(
            onRefresh: () => fetchMemberList(cls, uid),
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Column(
                children: <Widget>[
                  TeacherMemberList(teachers: getTeacherList(cls.members)),
                  StudentMemberList(students: getStudentList(cls.members)),
                ],
              ),
            ),
          );
  }
}
