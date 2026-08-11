class Course {
  final String id;
  final String name;
  final String description;
  final List<String>
  buttonIds; // e.g., ['BT-01', 'BT-01', 'BT-05'] for 20s start
  final String icon;

  Course({
    required this.id,
    required this.name,
    required this.description,
    required this.buttonIds,
    this.icon = 'stars_rounded',
  });
}

class CourseService {
  CourseService._();
  static final CourseService instance = CourseService._();

  final List<Course> _microwaveCourses = [
    Course(
      id: 'c1',
      name: '햇반 데우기',
      description: '1분 30초 조리 후 시작',
      buttonIds: ['BT-03', 'BT-02', 'BT-05'],
    ),
    Course(
      id: 'c2',
      name: '냉동 피자',
      description: '5분 조리 후 시작',
      buttonIds: ['BT-04', 'BT-05'],
    ),
    Course(
      id: 'c3',
      name: '우유 데우기',
      description: '우유 코스 시작',
      buttonIds: ['BT-08', 'BT-05'],
    ),
  ];

  List<Course> getCoursesForDevice(String type) {
    // 현재는 전자레인지 위주, 추후 확장 가능
    return _microwaveCourses;
  }
}
