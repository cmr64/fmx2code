FMX2Code is a tool to help you take design time .fmx files generated with Delphi/RAD Studio's inbuilt drag and drop editor, and convert them to dynamic Delphi code. 

**Usage**
1. Compile FMX2Code with Delphi 12.3+ (no dependencies)
2. Click "Load file" and select a .fmx file (forms or frames work)
3. You will see a list of objects detected in the file. Click on one to select it.
4. Change the settings at the bottom:
    - Generate children will also generate the object's child components. Leave off if you just want that singular object
    - Generate only properties will not generate a .Create for the object
5. Click generate and the dynamic code will appear in the memo