// TypeScript test file
interface User {
   id: number;
   name: string;
   email?: string;
 }

class UserService {
   private users: User[] = [];

   addUser(user: User): void {
      this.users.push(user);
   }

   getUserById(id): User | undefined {
      return this.users.find((user) => user.id === id);
   }

   // Intentional issues
   public getAllUsers() {  // missing return type
      var result = this.users;  // var instead of const

      return result;
   }

   test() {
      console.log('test');
      return 'test';
   }
}

const userService = new UserService();

userService.addUser({
   id: 1,
   name: 'John Doe'
});

// Unused variable
const unusedVariable: string = 'test';
