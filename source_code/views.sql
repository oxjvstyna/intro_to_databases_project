-- View: WEBINARS_FINANCIAL_REPORT
CREATE VIEW WEBINARS_FINANCIAL_REPORT
AS
SELECT w.WebinarID                        AS ID,
       w.Title                            AS Name,
       (SELECT ISNULL(SUM(wo.Price), 0)
        FROM WebinarOrders wo
        WHERE wo.WebinarID = w.WebinarID
          AND wo.PaymentDate IS NOT NULL) AS TotalIncome
FROM Webinars w
GO;

-- View: COURSES_FINANCIAL_REPORT
CREATE VIEW COURSES_FINANCIAL_REPORT
AS
SELECT c.CourseID                                  AS ID,
       c.Title                                     AS Name,
       (SELECT SUM(co.FullPrice)
        FROM CourseOrders co
        WHERE co.CourseID = c.CourseID
          AND co.PaymentDateFull IS NOT NULL) +
       (SELECT SUM(co.PaymentInAdvance)
        FROM CourseOrders AS co
        WHERE co.CourseID = c.CourseID
          AND co.PaymentDateFull IS NULL
          AND co.PaymentDateInAdvance IS NOT NULL) AS TotalIncome
FROM Courses c
GO;

-- View: STUDIES_FINANCIAL_REPORT
CREATE VIEW STUDIES_FINANCIAL_REPORT
AS
SELECT s.StudyID                           AS ID,
       s.Title                             AS Name,
       (SELECT SUM(so.Price)
        FROM StudyOrders so
        WHERE so.StudyID = s.StudyID
          AND so.PaymentDate IS NOT NULL) +
       (SELECT SUM(smo.Price)
        FROM StudyMeetingOrders smo
                 INNER JOIN StudyMeetings sm ON smo.MeetingID = sm.MeetingID
        WHERE sm.StudyID = s.StudyID
          AND smo.PaymentDate IS NOT NULL) AS TotalIncome
FROM Studies s
GO;

-- View: FINANCIAL_REPORT
CREATE VIEW FINANCIAL_REPORT
AS
SELECT *, 'Webinar' AS Type
FROM WEBINARS_FINANCIAL_REPORT
UNION
SELECT *, 'Course' AS Type
FROM COURSES_FINANCIAL_REPORT
UNION
SELECT *, 'Study' AS Type
FROM STUDIES_FINANCIAL_REPORT
GO;

-- View: FUTURE_WEBINARS_REPORT
CREATE VIEW FUTURE_WEBINARS_REPORT
AS
SELECT w.WebinarID AS ID,
       w.Title     AS Name,
       COUNT(*)    AS Participants
FROM Webinars w
         INNER JOIN WebinarOrders wo
                    ON w.WebinarID = wo.WebinarID
WHERE w.Date > GETDATE()
  AND wo.PaymentDate IS NOT NULL
GROUP BY w.WebinarID, w.Title
GO;

-- View: FUTURE_COURSE_MEETINGS_REPORT
CREATE VIEW FUTURE_COURSE_MEETINGS_REPORT
AS
SELECT cm.MeetingID AS ID,
       cm.Title     AS Name,
       COUNT(*)     AS Participants
FROM CourseMeetings cm
         INNER JOIN CourseModules cmod
                    ON cm.ModuleID = cmod.ModuleID
         INNER JOIN Courses c
                    ON cmod.CourseID = c.CourseID
         INNER JOIN CourseOrders co
                    ON c.CourseID = co.CourseID
WHERE cm.Date > GETDATE()
  AND (co.PaymentDateFull IS NOT NULL OR co.PaymentDateInAdvance IS NOT NULL)
GROUP BY cm.MeetingID, cm.Title
GO;

-- View: FUTURE_STUDY_MEETINGS_REPORT
CREATE VIEW FUTURE_STUDY_MEETINGS_REPORT
AS
SELECT sm.MeetingID AS ID,
       sm.Title     AS Name,
       COUNT(*)     AS Participants
FROM StudyMeetings sm
         INNER JOIN StudyMeetingOrders smo
                    ON sm.MeetingID = smo.MeetingID
WHERE sm.BeginDate > GETDATE()
  AND smo.PaymentDate IS NOT NULL
GROUP BY sm.MeetingID, sm.Title
GO;

-- View: FUTURE_EVENTS_REPORT
CREATE VIEW FUTURE_EVENTS_REPORT
AS
SELECT *, 'Webinar' AS Type
FROM FUTURE_WEBINARS_REPORT
UNION
SELECT *, 'Course meeting' AS Type
FROM FUTURE_COURSE_MEETINGS_REPORT
UNION
SELECT *, 'Study meeting' AS Type
FROM FUTURE_STUDY_MEETINGS_REPORT
GO;

-- View: CLASS_ATTENDANCE_REPORT
CREATE VIEW CLASS_ATTENDANCE_REPORT AS
SELECT ClassID                                                     AS ID,
       COUNT(CASE WHEN Attended = 1 THEN 1 END)                    AS PresentCount,
       COUNT(CASE WHEN Attended = 0 THEN 1 END)                    AS AbsentCount,
       COUNT(*)                                                    AS TotalParticipants,
       COUNT(CASE WHEN Attended = 1 THEN 1 END) * 100.0 / COUNT(*) AS AttendancePercentage
FROM ClassAttendance
GROUP BY ClassID
GO;

-- View: COURSE_MEETING_ATTENDANCE_REPORT
CREATE VIEW COURSE_MEETING_ATTENDANCE_REPORT AS
SELECT MeetingID                                                   AS ID,
       COUNT(CASE WHEN Attended = 1 THEN 1 END)                    AS PresentCount,
       COUNT(CASE WHEN Attended = 0 THEN 1 END)                    AS AbsentCount,
       COUNT(*)                                                    AS TotalParticipants,
       COUNT(CASE WHEN Attended = 1 THEN 1 END) * 100.0 / COUNT(*) AS AttendancePercentage
FROM CourseMeetingAttendance
GROUP BY MeetingID
GO;

-- View: INTERNSHIP_ATTENDANCE_REPORT
CREATE VIEW INTERNSHIP_ATTENDANCE_REPORT AS
SELECT InternshipID                                                AS ID,
       COUNT(CASE WHEN Attended = 1 THEN 1 END)                    AS PresentCount,
       COUNT(CASE WHEN Attended = 0 THEN 1 END)                    AS AbsentCount,
       COUNT(*)                                                    AS TotalParticipants,
       COUNT(CASE WHEN Attended = 1 THEN 1 END) * 100.0 / COUNT(*) AS AttendancePercentage
FROM InternshipAttendance
GROUP BY InternshipID
GO;

-- View: ATTENDANCE_REPORT
CREATE VIEW ATTENDANCE_REPORT AS
SELECT *, 'Internship' AS Type
FROM INTERNSHIP_ATTENDANCE_REPORT
UNION
SELECT *, 'Course meeting' AS Type
FROM COURSE_MEETING_ATTENDANCE_REPORT
UNION
SELECT *, 'Classes' AS Type
FROM CLASS_ATTENDANCE_REPORT
GO;

-- View: LIST_OF_DEBTORS
CREATE VIEW LIST_OF_DEBTORS AS
SELECT DISTINCT
    u.UserID AS StudentID,
    u.FirstName,
    u.LastName,
    u.Email,
    u.Phone
FROM Users u
WHERE u.UserID NOT IN (
    SELECT DISTINCT u.UserID
    FROM Users u
    JOIN Orders o ON u.UserID = o.UserID
    JOIN WebinarOrders wo ON o.OrderID = wo.OrderID
    JOIN Courses c ON wo.WebinarID = c.CourseID
    WHERE o.OrderDate < c.BeginDate

    UNION

    SELECT DISTINCT u.UserID
    FROM Users u
    JOIN Orders o ON u.UserID = o.UserID
    JOIN CourseOrders co ON o.OrderID = co.OrderID
    JOIN Courses c ON co.CourseID = c.CourseID
    WHERE o.OrderDate < DATEADD(DAY, -3,
        (SELECT MIN(cm.Date)
         FROM CourseMeetings cm
         WHERE cm.ModuleID = c.CourseID))

    UNION

    SELECT DISTINCT u.UserID
    FROM Users u
    JOIN Orders o ON u.UserID = o.UserID
    JOIN StudyOrders so ON o.OrderID = so.OrderID
    JOIN StudyMeetings sm ON sm.StudyID = so.StudyID
    WHERE o.OrderDate < DATEADD(DAY, -3,
        (SELECT MIN(sm.BeginDate)
         FROM StudyMeetings sm
         WHERE sm.StudyID = so.StudyID))

    UNION

    SELECT DISTINCT u.UserID
    FROM Users u
    JOIN Orders o ON u.UserID = o.UserID
    JOIN StudyMeetingOrders smo ON o.OrderID = smo.OrderID
    JOIN CourseMeetings cm ON smo.MeetingID = cm.MeetingID
    WHERE o.OrderDate < DATEADD(DAY, -3,
        (SELECT cm.Date
         FROM CourseMeetings cm
         WHERE cm.MeetingID = smo.MeetingID))
)
AND u.UserID IN (
    SELECT DISTINCT u.UserID
    FROM Users u
    JOIN WebinarOrders wo ON u.UserID = wo.OrderID
    UNION
    SELECT DISTINCT u.UserID
    FROM Users u
    JOIN CourseOrders co ON u.UserID = co.OrderID
    UNION
    SELECT DISTINCT u.UserID
    FROM Users u
    JOIN StudyOrders so ON u.UserID = so.OrderID
    UNION
    SELECT DISTINCT u.UserID
    FROM Users u
    JOIN StudyMeetingOrders smo ON u.UserID = smo.OrderID
);
GO;

-- View: STUDENTS_REGISTERED_FOR_COLLIDING_FUTURE_EVENTS_LIST
CREATE VIEW STUDENTS_REGISTERED_FOR_COLLIDING_FUTURE_EVENTS_LIST AS
SELECT DISTINCT
    u.UserID AS StudentID,
    u.FirstName,
    u.LastName
FROM Users AS u
    JOIN Orders o ON o.UserID = u.UserID
    JOIN WebinarOrders AS wo ON o.OrderID = wo.OrderID
    JOIN Webinars AS w ON wo.WebinarID = w.WebinarID
    JOIN Webinars AS w2 ON w.WebinarID <> w2.WebinarID
    AND ((CASE WHEN w2.Date > w.Date THEN w2.Date ELSE w.Date END) <
        (CASE WHEN DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', w2.Duration), w2.Date) <
                      DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', w.Duration), w.Date)
              THEN DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', w2.Duration), w2.Date)
              ELSE DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', w.Duration), w.Date) END))

    JOIN CourseOrders AS co ON o.OrderID = co.OrderID
    JOIN Courses AS c ON co.CourseID = c.CourseID
    JOIN CourseModules cm ON cm.CourseID = c.CourseID
    JOIN CourseMeetings cms ON cm.ModuleID = cms.ModuleID
    JOIN CourseMeetings AS cms2 ON cms.MeetingID <> cms2.MeetingID
    AND ((CASE WHEN cms2.Date > cms.Date THEN cms2.Date ELSE cms.Date END) <
        (CASE WHEN DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cms2.Duration), cms2.Date) <
                      DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cms.Duration), cms.Date)
              THEN DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cms2.Duration), cms2.Date)
              ELSE DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cms.Duration), cms.Date) END))

    JOIN StudyMeetingOrders AS smo ON o.OrderID = smo.OrderID
    JOIN StudyMeetings AS sm ON smo.MeetingID = sm.MeetingID
    JOIN Classes AS cl ON cl.MeetingID = sm.MeetingID
    JOIN Classes as cl2 ON cl.MeetingID <> cl2.MeetingID
    AND ((CASE WHEN cl2.Date > cl.Date THEN cl2.Date ELSE cl.Date END) <
        (CASE WHEN DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cl2.Duration), cl2.Date) <
                      DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cl.Duration), cl.Date)
              THEN DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cl2.Duration), cl2.Date)
              ELSE DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cl.Duration), cl.Date) END))
WHERE EXISTS (
    SELECT w.WebinarID
    WHERE EXISTS (
        SELECT c.CourseID
        WHERE ((CASE WHEN cms.Date > w.Date THEN cms.Date ELSE w.Date END) <
            (CASE WHEN DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cms.Duration), cms.Date) <
                          DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', w.Duration), w.Date)
                  THEN DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cms.Duration), cms.Date)
                  ELSE DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', w.Duration), w.Date) END))
    )
    UNION
    SELECT w.WebinarID
    WHERE EXISTS (
        SELECT sm.MeetingID
        WHERE ((CASE WHEN cl.Date > w.Date THEN cl.Date ELSE w.Date END) <
            (CASE WHEN DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cl.Duration), cl.Date) <
                          DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', w.Duration), w.Date)
                  THEN DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cl.Duration), cl.Date)
                  ELSE DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', w.Duration), w.Date) END))
    )
    UNION
    SELECT cm.ModuleID
    WHERE EXISTS (
        SELECT sm.MeetingID
        WHERE ((CASE WHEN cl.Date > cms.Date THEN cl.Date ELSE cms.Date END) <
            (CASE WHEN DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cl.Duration), cl.Date) <
                          DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cms.Duration), cms.Date)
                  THEN DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cl.Duration), cl.Date)
                  ELSE DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', cms.Duration), cms.Date) END))
    )
);
GO;
