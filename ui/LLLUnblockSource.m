            NSString *raw = [[NSString alloc] initWithData:d2 encoding:NSUTF8StringEncoding];
            if (!raw) raw = @"";
            NSString *uStr = [raw stringByTrimmingCharactersInSet:
                              NSCharacterSet.whitespaceAndNewlineCharacterSet];
