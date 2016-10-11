# create results table to store id and max value
##CREATE TABLE benzo_final (MEMBER_MEDICAID_ID VARCHAR(255), MAX_DAYS INT);

DELIMITER $$ #set a custom delimiter for parent scope

# overwrite procedure, ends with our custom delimiter since its in parent scope
DROP PROCEDURE IF EXISTS some_looping$$

# we need a stored procedure so that we can do the fancier logic like cursors
CREATE PROCEDURE some_looping()  # arbitrary name
BEGIN

    # prep variable to hold the id from the first query as we step thru row by row
    DECLARE selected_id VARCHAR(255) DEFAULT "";

    # prepare to handle the sitatuation where the cursor reaches the end and there are no more rows
    DECLARE finished INTEGER DEFAULT 0;

    # create the cursor and fill it's buffer with all ids
    DECLARE the_cursor CURSOR FOR (SELECT DISTINCT `MEMBER_MEDICAID_ID` FROM benzo_test);

    # handle the exception for an empty cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;

    # start working our way through all the unique ids, row by row
    OPEN the_cursor;

    # loop thru each unique id
    get_id: LOOP

        # store unique id into a variable
        FETCH the_cursor INTO selected_id;

        # check if were at the end of the rows, if so, exit, if not, keep going
        IF finished = 1 THEN 
            LEAVE get_id;
        END IF;

        # create a temporary table of all data for just one id
        CREATE TEMPORARY TABLE selected_person AS
            (SELECT `MEMBER_MEDICAID_ID`, `FIRST_DATE_OF_SERVICE`, `END_DATE` 
             FROM benzo_test
             WHERE `MEMBER_MEDICAID_ID` = selected_id);
        
        # variable to store max consecutive days for person/id
        SET @max_day_count = 0;
        SET @consecutive_day_count = 0;
        
        # variables to store start, end, and current iterator date
        SET @first_date = "2014-01-01 00:00:00";
        SET @last_date = "2014-12-31 00:00:00";
        SET @selected_date = @first_date;
        
        # loop thru each date in date range for persons temp table
        WHILE @selected_date <= @last_date DO

            # set variable with count of drugs person is taking for current date
            SET @ON_PRESCRIPTION = (SELECT COUNT(*)
                FROM selected_person
                WHERE `FIRST_DATE_OF_SERVICE` <= @selected_date
                AND @selected_date <= `END_DATE`);

            # if person is on a drug then increment day count
            IF @ON_PRESCRIPTION > 0 THEN
                SET @consecutive_day_count = @consecutive_day_count + 1;
            ELSE
                IF @consecutive_day_count > @max_day_count THEN
                    SET @max_day_count = @consecutive_day_count;
                END IF;
                SET @consecutive_day_count = 0;
            END IF;

           # increment date  
           SET @selected_date = DATE_ADD(@selected_date, INTERVAL 1 DAY);

        END WHILE; # end looping thru days

        # release temporary table of person data
        DROP TABLE IF EXISTS selected_person;

        # store max variable per unique id
        INSERT INTO benzo_final (MEMBER_MEDICAID_ID, MAX_DAYS) VALUES(selected_id, @max_day_count);

    END LOOP get_id; # end looping thru unique ids

    # free cursor
    CLOSE the_cursor;

END$$ # end stored procedure

DELIMITER ; # restore default delimiter

CALL some_looping(); # call the stored procedure
