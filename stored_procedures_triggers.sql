DROP TRIGGER IF EXISTS salary;
DELIMITER &
CREATE TRIGGER salary
BEFORE INSERT 
ON Worker
FOR EACH ROW 
BEGIN
	IF new.salary IS NULL THEN	
	SET new.salary = 650 AND new.initial_salary = 650;
	END IF;
END& 
DELIMITER ;



CREATE TRIGGER issue_space 
BEFORE UPDATE 
ON Article 
FOR EACH ROW
BEGIN 
	DECLARE issue_pages INT;
	DECLARE pages_filled INT;
	DECLARE Nopages INT;
	DECLARE not_found INT;
	DECLARE bcursor CURSOR FOR
	SELECT No_of_pages FROM Article where Issue_No = new.Issue_No and Newspaper_Name = new.Newspaper_Name;
	
	DECLARE CONTINUE HANDLER FOR NOT FOUND
	SET not_found=1;
	
	SET not_found=0;
	set pages_filled =0;
	
	OPEN bcursor;	
	
	REPEAT
			FETCH bcursor INTO Nopages;
			IF(not_found=0)
			THEN
				SET pages_filled = pages_filled + Nopages;
			END IF;
		UNTIL(not_found=1)
	END REPEAT;
		
	
	SET issue_pages = ( SELECT No_of_pages 
						FROM Issue 
						WHERE Issue_No = new.Issue_No AND Newspaper_Name = new.Newspaper_Name);
	IF issue_pages - pages_filled - new.No_of_pages < 0 
	THEN 
		SIGNAL SQLSTATE VALUE '45000'
		SET MESSAGE_TEXT = 'Not enough pages left'; 
	END IF;
END& 
DELIMITER ;

/////////////////////////////////////////////////////////////////////

drop procedure if exists getKeywords;
delimiter &
create procedure getKeywords(mypath varchar(255))
begin 
	select key_word 
	from article_key_word
	where article_path = mypath ; 
end&
delimiter ;

DROP PROCEDURE IF EXISTS insert_journalist;
DELIMITER &
CREATE PROCEDURE insert_journalist(pre_occupation int, bio varchar(255), name varchar(255), last_name varchar(255), email varchar(255), salary int, newspaper_name varchar(255), password VARCHAR(255))
BEGIN
	INSERT INTO Worker VALUES (Name, last_name, email, SYSDATE(), salary, newspaper_name, password, salary);
	INSERT INTO Journalist VALUES (pre_occupation, bio, email);
END&
DELIMITER ;


DROP PROCEDURE IF EXISTS insert_administrative;
DELIMITER &
CREATE PROCEDURE insert_administrative(duties varchar(255), street varchar(255), street_no int, city varchar(255), name varchar(255), last_name varchar(255), email varchar(255), salary int, newspaper_name varchar(255), password VARCHAR(255))
BEGIN
	INSERT INTO Worker VALUES (Name, last_name, email, SYSDATE(), salary, newspaper_name, password, salary);
	INSERT INTO administrative VALUES (duties, street, street_no, city, email);
END&
DELIMITER ;

DROP PROCEDURE IF EXISTS new_salary;
DELIMITER &
CREATE PROCEDURE new_salary(mail varchar(255))
BEGIN
    DECLARE datediff INT;
    DECLARE preoccupation INT;
    DECLARE months INT;
    DECLARE work INT;
    DECLARE salar INT;
    DECLARE salary_raise INT;
    
    SET preoccupation = (SELECT pre_occupation_at_assignment FROM Journalist WHERE email = mail);
    SET salar = (SELECT initial_salary FROM Worker WHERE email = mail);
    SET salary_raise = 0;
    SELECT DATEDIFF( SYSDATE() , Worker.Date_of_Recruitment) into datediff FROM Worker WHERE email = mail;
    
    SET months = (datediff / 30);
    SELECT Date_of_Recruitment , SYSDATE() FROM Worker WHERE email = mail;
    SET work = preoccupation + months;
    
    
    SET salary_raise = (salary_raise + salar * work * 0.005);
    SELECT salary_raise;
	UPDATE Worker SET Salary = salary_raise WHERE email=mail;
     
END &
DELIMITER ; 



DROP PROCEDURE IF EXISTS showAllIssueArticlesWithDetails; ######## Project procedure a.
DELIMITER $
CREATE PROCEDURE showAllIssueArticlesWithDetails(issue_number INT, newspaper VARCHAR(255))
BEGIN # rest of the code
    DECLARE issue_pages INT;
    DECLARE article_starting_page INT DEFAULT 1;
    DECLARE articles_pages INT;
    DECLARE not_found INT DEFAULT 0;
    DECLARE counter INT DEFAULT 1;

    DECLARE bcursor CURSOR FOR
    SELECT No_of_pages FROM Article
    WHERE Article.Issue_No = issue_number AND Article.Newspaper_Name = newspaper
    ORDER BY article_order;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET not_found=1;

    SELECT No_of_pages INTO issue_pages FROM Issue
    WHERE Issue_No = issue_number AND Issue.Newspaper_Name=newspaper;

    CREATE TEMPORARY TABLE Necessary
    SELECT article_path, article_order
    FROM Article
    WHERE Issue_No = issue_number AND Newspaper_Name = newspaper;
    ALTER TABLE Necessary ADD starting_page INT AFTER article_order;

    OPEN bcursor;

    REPEAT 
        FETCH bcursor INTO articles_pages;
        UPDATE necessary 
        SET 
            starting_page = article_starting_page 
        WHERE article_order = counter;

        SET counter = counter + 1;
        SET article_starting_page = article_starting_page + articles_pages;
    UNTIL(not_found=1)
    END REPEAT;

    SELECT Article.Title, Article.Editor_in_chief, Article.Approval_Date, Necessary.starting_page, Article.No_of_pages FROM Article
    INNER JOIN Necessary
    ON Article.article_path = Necessary.article_path
    ORDER BY starting_page;
    DROP TABLE Necessary;
END $
DELIMITER ;

DROP PROCEDURE IF EXISTS validatePassword;
DELIMITER $
CREATE PROCEDURE validatePassword(email VARCHAR(255))
BEGIN
	SELECT password,attribute FROM Passwords 
	WHERE username = email;
END $
DELIMITER ;

DROP PROCEDURE IF EXISTS insertCoAuthor;
DELIMITER $ 
CREATE PROCEDURE insertCoAuthor(articlepath VARCHAR(255), coauthor VARCHAR(255))
BEGIN
	INSERT INTO Submits VALUES
	(current_timestamp,articlepath,coauthor);
END $
DELIMITER ;
DROP PROCEDURE IF EXISTS getCategoryCode;
DELIMITER $
CREATE PROCEDURE getCategoryCode(category VARCHAR(255))
BEGIN
	SELECT code FROM Category WHERE Category.Name = category;
END $
DELIMITER ;


DROP PROCEDURE IF EXISTS showRestJournalists;
DELIMITER $
CREATE PROCEDURE showRestJournalists(email VARCHAR(255))
BEGIN 
	DECLARE newspaper VARCHAR(255);
	DECLARE editors VARCHAR(255);	
	SELECT Newspaper_Name INTO newspaper FROM Worker WHERE Worker.email=email;
	
	SELECT Journalist.email FROM Journalist
	INNER JOIN Worker ON Journalist.email = Worker.email
	LEFT JOIN Editor_in_chief ON Journalist.email = Editor_in_chief.email
	WHERE Journalist.email != email AND Worker.Newspaper_Name=newspaper ;
END $
DELIMITER ;


DROP PROCEDURE IF EXISTS insertArticleAsJournalist;
DELIMITER $
CREATE PROCEDURE insertArticleAsJournalist(article_path VARCHAR(255), 
											Title VARCHAR(255),
											Summary VARCHAR(255),
											Photos VARCHAR(255),
											Category INT,											
											No_of_pages INT,
											email VARCHAR(255))
BEGIN

	DECLARE newspaper VARCHAR(255);
	DECLARE editor VARCHAR(255);
	SELECT Newspaper_Name INTO newspaper FROM Worker WHERE Worker.email=email;
	
	SELECT Editor_in_chief.email INTO editor FROM Editor_in_chief WHERE Newspaper_Name = newspaper;
	INSERT INTO Article VALUES
	(article_path,Title,Summary,NULL,NULL,'NOT CHECKED',editor,No_of_pages,Photos,1,newspaper,Category,NULL);

	INSERT INTO Submits VALUES
	(current_timestamp,article_path,email);
END $
DELIMITER ;


DROP PROCEDURE IF EXISTS insertArticleAsEditor;
DELIMITER $
CREATE PROCEDURE insertArticleAsEditor(article_path VARCHAR(255),
                                        Title VARCHAR(255),
                                        Summary VARCHAR(255),
                                        No_of_pages INT,
                                        Photos VARCHAR(255),
                                        Category INT,
                                        email VARCHAR(255)
                                        )
BEGIN

    DECLARE newspaper VARCHAR(255);
    SELECT Newspaper_Name INTO newspaper FROM Worker WHERE Worker.email=email;
    
    INSERT INTO Article VALUES
    (article_path,Title,Summary,NULL,NULL,'APPROVED',email,No_of_pages,Photos,NULL,newspaper,Category,SYSDATE());

END$
DELIMITER ;



DROP PROCEDURE IF EXISTS updateCheckStatus;
DELIMITER $
CREATE PROCEDURE updateCheckStatus(my_article_path VARCHAR(255), checkStatus VARCHAR(255))
BEGIN
		UPDATE Article
		SET checked_or_not = checkStatus , Approval_Date = SYSDATE()
		WHERE article_path = my_article_path;
END $
DELIMITER ;



DROP PROCEDURE IF EXISTS updateArticle;
DELIMITER $
CREATE PROCEDURE updateArticle(articlepath VARCHAR(255),
								new_title VARCHAR(255),
								new_summary VARCHAR(255),
								new_no_of_pages INT,
								new_photos VARCHAR(255),
								new_category INT,
								email VARCHAR(255))
BEGIN

	DECLARE newspaper VARCHAR(255);
	SELECT Newspaper_Name INTO newspaper FROM Worker WHERE Worker.email=email;

	UPDATE Article
	SET 
	Title = new_title,
	Summary = new_summary,
	No_of_pages = new_no_of_pages,
	Photos = new_photos,
	Category = new_category
	WHERE Article.Newspaper_Name = newspaper AND Article.article_path = articlepath;

	DELETE FROM Article_key_word WHERE article_path = articlepath ;
	DELETE FROM Submits WHERE article_path = articlepath AND author != email;

END$
DELIMITER ;



DROP PROCEDURE IF EXISTS showAllIssues;
DELIMITER $
CREATE PROCEDURE showAllIssues(email VARCHAR(255))
BEGIN
	DECLARE newspaper VARCHAR(255);
	SELECT Newspaper_Name INTO newspaper FROM Worker WHERE Worker.email=email;

	SELECT Issue_No FROM Issue
	WHERE Newspaper_Name = newspaper;
END $
DELIMITER ;



DROP PROCEDURE IF EXISTS showArticle;
DELIMITER $
CREATE PROCEDURE showArticle(articlepath VARCHAR(255))
BEGIN
	SELECT * FROM Article 
	WHERE article_path = articlepath;
END $
DELIMITER ;



DROP PROCEDURE IF EXISTS showAllJournalistArticles;
DELIMITER $
CREATE PROCEDURE showAllJournalistArticles(journalist_email VARCHAR(255))
BEGIN
	SELECT Article.article_path FROM Article
	INNER JOIN Submits 
	ON Submits.article_path = Article.article_path
	WHERE journalist_email = Submits.author;
END $
DELIMITER ; 


DROP PROCEDURE IF EXISTS showAllOwnedNewspapers;
DELIMITER $
CREATE PROCEDURE showAllOwnedNewspapers(IN username VARCHAR(255))
BEGIN
	SELECT Name FROM Newspaper WHERE Owner = username;
END $
DELIMITER ;



DROP PROCEDURE IF EXISTS showAllNewspaperJournalists;
DELIMITER $
CREATE PROCEDURE showAllNewspaperJournalists(newspaper VARCHAR(255))
BEGIN 
	SELECT Worker.Name,Worker.Last_name FROM Journalist
	INNER JOIN Worker 
	ON Worker.email = Journalist.email
	WHERE Worker.Newspaper_Name = newspaper;
END $
DELIMITER ; 


drop procedure if exists showAllArticles;
delimiter &
create procedure showAllArticles(mail varchar(255))
begin 
	declare name varchar(255);
	set name = (select Newspaper_Name from Worker where email = mail);
	select article_path from Article where Newspaper_Name = name ;

end &

delimiter ;


DROP PROCEDURE IF EXISTS showAllArticlesNotInIssue;
DELIMITER $ 
CREATE PROCEDURE showAllArticlesNotInIssue(editor varchar(255),issue INT)
BEGIN
	SELECT article_path,No_of_pages FROM Article 
	WHERE editor_in_chief = editor AND (Article.Issue_No != issue OR Article.Issue_No IS NULL);
END $
DELIMITER ;

DROP PROCEDURE IF EXISTS getNumberOfPages;
DELIMITER $ 
CREATE PROCEDURE getNumberOfPages(mail VARCHAR(255),issue INT)
BEGIN
	SELECT No_of_pages FROM Issue 
	WHERE Newspaper_Name = (select Newspaper_Name from Worker Where email = mail) AND Issue_No = issue ;
END $
DELIMITER ;


DROP PROCEDURE IF EXISTS updateComments;
DELIMITER $ 
CREATE PROCEDURE updateComments(articlepath VARCHAR(255),new_comments VARCHAR(255))
BEGIN
	UPDATE Article
	SET   revision_comments = new_comments
	WHERE article_path = articlepath;
END $
DELIMITER ;



DROP PROCEDURE IF EXISTS showAllCategories;
DELIMITER $
CREATE PROCEDURE showAllCategories()
BEGIN
	SELECT Name FROM Category;
END $
DELIMITER ;



DROP PROCEDURE IF EXISTS insertNewCategory;
DELIMITER $
CREATE PROCEDURE insertNewCategory(name VARCHAR(255),description VARCHAR(255),is_child_of INT)
BEGIN 
	IF is_child_of != 0 THEN
		INSERT INTO Category VALUES (NULL,name,description,is_child_of);
	
	ELSE
		INSERT INTO Category VALUES (NULL,name,description,NULL);
	END IF;	
END $
DELIMITER ;



DROP PROCEDURE IF EXISTS insertReturnedCopies;
DELIMITER $ 
CREATE PROCEDURE insertReturnedCopies(issueno INT ,returned_copies INT,email VARCHAR(255))
BEGIN
	DECLARE newspaper VARCHAR(255);
	SELECT Newspaper_Name INTO newspaper FROM Worker WHERE Worker.email=email;


	UPDATE Issue
	SET  Returned_copies = returned_copies
	WHERE Issue_no = issueno AND Newspaper_Name = newspaper;
END $
DELIMITER ;



DROP PROCEDURE IF EXISTS showTotalExpenses;
DELIMITER $
CREATE PROCEDURE showTotalExpenses(first_month int , second_month int)
BEGIN
	DECLARE month INT;
	DECLARE Total_expenses INT;
	SET month = second_month - first_month + 1;
	SET Total_expenses = month * ( SELECT SUM(salary) FROM Worker);

	SELECT Total_expenses;
END $
DELIMITER ; 	
	 


DROP PROCEDURE IF EXISTS updateNewspaper;
DELIMITER $
CREATE PROCEDURE updateNewspaper(NewsName VARCHAR(255),PublicationFrequency VARCHAR(20) , NewOwner VARCHAR(255))
BEGIN
	UPDATE Newspaper SET Publication_Frequency = PublicationFrequency , Owner = NewOwner WHERE Name = NewsName;
END $
DELIMITER ;



DROP PROCEDURE IF EXISTS insertNumberOfCopies;
DELIMITER $ 
CREATE PROCEDURE insertNumberOfCopies(issue INT,copies INT, Newspaper VARCHAR(255))
BEGIN
	
	UPDATE Issue
	SET Printed_Copies = copies
	WHERE Issue_No = issue AND Newspaper_Name = Newspaper;
END $
DELIMITER ;



DROP PROCEDURE IF EXISTS insertPriorityNumber;
DELIMITER & 
CREATE PROCEDURE insertPriorityNumber(articlepath varchar(255),priority int,issueno int)
BEGIN
	UPDATE Article
	SET  article_order = priority , Issue_No = issueno
	WHERE Article_Path = articlepath;
END &
DELIMITER ;




DROP PROCEDURE IF EXISTS addKeyWords;
DELIMITER $ 
CREATE PROCEDURE addKeyWords(articlepath VARCHAR(255),keyword VARCHAR(255))
BEGIN
	INSERT INTO Article_key_word VALUES (articlepath,keyword);
END $
DELIMITER ;



DROP PROCEDURE IF EXISTS promotion;
DELIMITER & 
CREATE PROCEDURE promotion(email varchar(255))
BEGIN
	DECLARE paper varchar(255);
	
	SET paper = (SELECT Worker.Newspaper_Name FROM Worker WHERE Worker.email = email );
	
	UPDATE Editor_in_chief 
	SET Editor_in_chief.email = email WHERE Editor_in_chief.Newspaper_Name = paper;
END &
DELIMITER ;

DROP PROCEDURE IF EXISTS getCatName;
DELIMITER $
CREATE PROCEDURE getCatName(IN cod INT)
BEGIN
	SELECT Name FROM Category WHERE code = cod ;
END $
DELIMITER ;

DROP PROCEDURE IF EXISTS showAllIssuesPub;
DELIMITER $
CREATE PROCEDURE showAllIssuesPub(Newspaper VARCHAR(255))
BEGIN
	
	SELECT Issue_No FROM Issue
	WHERE Newspaper_Name = Newspaper;
END $
DELIMITER ;

DROP PROCEDURE IF EXISTS showOldEditor;
DELIMITER $
CREATE PROCEDURE showOldEditor(Newspaper VARCHAR(255))
BEGIN
	
	SELECT Name, Last_Name FROM Editor_in_chief
	INNER JOIN Worker ON Worker.email = Editor_in_chief.email
	WHERE Worker.Newspaper_Name = Newspaper;
END $
DELIMITER ;

DROP PROCEDURE IF EXISTS nameToEmail;
DELIMITER $
CREATE PROCEDURE nameToEmail(Name VARCHAR(255),lastname VARCHAR(255))
BEGIN
	
	SELECT email FROM Worker
	WHERE Name = Name and Last_Name = lastname;
END $
DELIMITER ;

DROP PROCEDURE IF EXISTS totalSold;
DELIMITER $
CREATE PROCEDURE totalSold(Newspaper VARCHAR(255),issueno INT)
BEGIN
	SELECT Printed_Copies - Returned_Copies AS SOLD FROM Issue 
	WHERE Newspaper_Name = Newspaper AND Issue_No = issueno;
	
END $
DELIMITER ;

DROP PROCEDURE if exists showAllNewspaperExpenses;
DELIMITER &
CREATE PROCEDURE showAllNewspaperExpenses(first_month DATE , second_month DATE, em VARCHAR(255))
BEGIN 
	DECLARE all_salary INT;
	DECLARE paper VARCHAR(255);
	DECLARE months INT;
	DECLARE datediff INT;
	
	SELECT DATEDIFF( second_month , first_month ) INTO datediff;
	SET months = (datediff / 30);
	
	SET paper = (SELECT Newspaper_Name FROM Worker WHERE email = em);
	
	SET all_salary = months * ( SELECT sum(salary) FROM Worker WHERE Newspaper_Name = paper);
	SELECT all_salary;
END&
DELIMITER ; 	

DROP PROCEDURE IF EXISTS showNewspaperExpensesPerEmployee;
DELIMITER &
CREATE PROCEDURE showNewspaperExpensesPerEmployee(first_month DATE , second_month DATE, em VARCHAR(255))
BEGIN 
	DECLARE months INT;
	DECLARE datediff INT;
	DECLARE all_salary INT ;
	DECLARE paper VARCHAR(255);
	
	SELECT DATEDIFF( second_month , first_month ) into datediff;
	SET months = (datediff / 30);
	
	
	SET paper = (SELECT Newspaper_Name FROM Worker WHERE email = em);
		
	SELECT Worker.name AS name , Worker.last_name AS last_name , salary * months AS cost FROM Worker WHERE Newspaper_Name = paper;	
END&
DELIMITER ; 

